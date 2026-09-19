import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../models/category_base.dart';
import '../models/todo.dart';
import '../models/todo_category.dart';
import '../services/category_store.dart';
import '../services/supabase_service.dart';
import '../services/todo_repository.dart';
import '../widgets/categorize_overlay.dart';
import '../widgets/swipe_action_card.dart';
import '../widgets/sync_indicator.dart';
import 'edit_categories_screen.dart';
import 'home_shell.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  static const List<String> _surpriseDescriptions = [
    'Monitore suas tarefas',
    'O que vamos conquistar hoje?',
    'Pequenos passos, grandes resultados.',
    'Tudo em ordem, uma tarefa de cada vez.',
    'Seu dia começa aqui.',
    'Hora de fazer acontecer.',
    'Organize. Execute. Repita.',
    'Nada escapa da sua lista.',
    'Mais foco, menos preocupação.',
    'Transforme planos em conquistas.',
    'Seu futuro agradece.',
    'Missão do dia: avançar.',
    'Cada tarefa concluída conta.',
    'Produtividade sem complicação.',
    'Seu segundo cérebro.',
    'A próxima vitória está na lista.',
    'Comece por qualquer lugar.',
    'Só falta dar o primeiro passo.',
    'Um check de cada vez.',
    'Menos bagunça, mais progresso.',
    'Respire. Priorize. Faça.',
    'Hoje é um bom dia para terminar pendências.',
    'Tudo pronto para um dia produtivo?',
    'Vamos riscar alguns itens?',
    'Seu plano está esperando.',
    'Não deixe para depois.',
    'O impossível começa com uma tarefa.',
    'Mais ação, menos procrastinação.',
    'Qual será a próxima conquista?',
    'Seu tempo vale ouro.',
    'Você está no controle.',
    'Uma lista organizada, uma mente tranquila.',
    'Foco no que realmente importa.',
    'Cada tarefa é um passo à frente.',
    'A consistência vence.',
    'Organização é liberdade.',
    'Faça do hoje um bom dia.',
    'Sua produtividade mora aqui.',
    'Pronto para marcar alguns ✓?',
    'Vamos deixar essa lista menor?',
    'Uma tarefa a menos, um sorriso a mais.',
    'Seu eu do futuro vai agradecer.',
    'Não pare agora.',
    'A próxima tarefa é a mais importante.',
    'O progresso acontece aos poucos.',
    'Tudo fica mais fácil quando está organizado.',
    'Seu painel de missões.',
    'Que comece a produtividade.',
    'Nada como um bom checklist.',
    'Vamos fazer acontecer.',
  ];

  List<Todo> _todos = [];
  List<TodoCategory> _categories = [];
  bool _isLoading = true;
  bool _isAdding = false;
  // UI-only grouping: never touches the stored order. The flag and the
  // group order live in SharedPreferences; collapse state is per-session.
  static const String _uncategorizedKey = '__uncategorized__';
  static const String _prefGroupByCategory = 'todo_group_by_category';
  static const String _prefGroupOrder = 'todo_group_order';
  bool _groupByCategory = false;
  List<String> _groupOrder = [];
  final Set<String> _collapsedGroups = {};
  bool _searchVisible = false;
  final _searchController = TextEditingController();
  String _surpriseDescription = _surpriseDescriptions[
      Random().nextInt(_surpriseDescriptions.length)];
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  // Focused whenever this tab is active and the add/categorize field isn't,
  // so Space can be used to bring up the "add" field from the keyboard.
  final _screenFocusNode = FocusNode();
  StreamSubscription? _authSubscription;

  // Categorize overlay state
  Todo? _categorizingTodo;
  final _overlayKey = GlobalKey<CategorizeOverlayState>();

  TodoRepository get _repo => TodoRepository.instance;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadGroupPrefs();
    _focusNode.onKeyEvent = _handleAddFieldKeyEvent;

    // New surprise description whenever the user switches tabs. The screen
    // stays alive in the IndexedStack, so initState alone isn't enough.
    homeTabIndex.addListener(_pickSurpriseDescription);
    // Reclaim keyboard focus when the user tabs back to this screen, so the
    // Space shortcut keeps working after visiting another tab.
    homeTabIndex.addListener(_onTabChanged);

    // Reload whenever the local cache changes (own writes or background
    // sync pulling fresh data from the server).
    _repo.onChange.addListener(_loadAll);

    _authSubscription = SupabaseService.authDataChanges.listen((data) {
      if (mounted) {
        setState(() {});
        _loadAll();
      }
    }, onError: (error) {
      if (SupabaseService.isNetworkError(error)) showNoInternetBanner();
    });
  }

  @override
  void dispose() {
    homeTabIndex.removeListener(_pickSurpriseDescription);
    homeTabIndex.removeListener(_onTabChanged);
    _repo.onChange.removeListener(_loadAll);
    _authSubscription?.cancel();
    _textController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  void _pickSurpriseDescription() {
    if (!mounted) return;
    setState(() {
      _surpriseDescription = _surpriseDescriptions[
          Random().nextInt(_surpriseDescriptions.length)];
    });
  }

  void _onTabChanged() {
    if (homeTabIndex.value == 0 && !_isAdding) {
      _screenFocusNode.requestFocus();
    }
  }

  // --- Keyboard shortcuts (Windows) ---

  /// Space brings up the add-todo field, mirroring the FAB.
  KeyEventResult _handleScreenKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.space &&
        _isAuthenticated &&
        !_isAdding &&
        _categorizingTodo == null) {
      _startAdding();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Escape dismisses the add-todo field, same as tapping outside of it.
  KeyEventResult _handleAddFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _saveAndStopAdding();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  Future<void> _loadAll() async {
    if (!_isAuthenticated) {
      if (mounted) {
        setState(() {
          _todos = [];
          _categories = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        _repo.getTodos(),
        _repo.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _todos = results[0] as List<Todo>;
          _categories = results[1] as List<TodoCategory>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Grouping preferences ---

  Future<void> _loadGroupPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _groupByCategory =
          prefs.getBool(_prefGroupByCategory) ?? false;
      _groupOrder = prefs.getStringList(_prefGroupOrder) ?? [];
    });
  }

  Future<void> _toggleGroupByCategory() async {
    setState(() => _groupByCategory = !_groupByCategory);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefGroupByCategory, _groupByCategory);
  }

  Future<void> _saveGroupOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefGroupOrder, _groupOrder);
  }

  /// Saved order pruned to existing categories, with new categories
  /// appended and "Sem categoria" defaulting to the bottom.
  List<String> _effectiveGroupOrder() {
    final known = <String>{
      for (final c in _categories) c.id,
      _uncategorizedKey,
    };
    final order = _groupOrder.where(known.contains).toList();
    for (final c in _categories) {
      if (!order.contains(c.id)) order.add(c.id);
    }
    if (!order.contains(_uncategorizedKey)) {
      order.add(_uncategorizedKey);
    }
    return order;
  }

  /// Todos shown in the list: everything, or the search matches (by
  /// title or category name) while the search bar is open.
  List<Todo> get _visibleTodos {
    final query = _searchController.text.trim().toLowerCase();
    if (!_searchVisible || query.isEmpty) return _todos;
    return _todos.where((t) {
      final cat = _categoryForTodo(t);
      return t.title.toLowerCase().contains(query) ||
          (cat?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) _searchController.clear();
    });
  }

  void _toggleGroupCollapsed(String key) {
    setState(() {
      if (_collapsedGroups.contains(key)) {
        _collapsedGroups.remove(key);
      } else {
        _collapsedGroups.add(key);
      }
    });
  }

  Future<void> _addTodo() async {
    final title = _textController.text.trim();
    if (title.isEmpty) return;
    _textController.clear();
    await _repo.addTodo(title);
  }

  Future<void> _toggleTodo(Todo todo) async {
    await _repo.toggleTodo(todo.id, !todo.isCompleted);
  }

  Future<void> _deleteTodo(Todo todo) async {
    // Archive instead of delete: the row is kept in the database.
    await _repo.archiveTodo(todo.id);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _todos.removeAt(oldIndex);
      _todos.insert(newIndex, item);
    });
    _repo.reorderTodos(_todos.map((t) => t.id).toList());
  }

  void _startAdding() {
    setState(() => _isAdding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _saveAndStopAdding() {
    final title = _textController.text.trim();
    if (title.isNotEmpty) _addTodo();
    _textController.clear();
    setState(() => _isAdding = false);
    _screenFocusNode.requestFocus();
  }

  // --- Categorize overlay ---

  void _startCategorize(Todo todo) {
    if (_categories.isEmpty) return;
    setState(() => _categorizingTodo = todo);
  }

  void _onCategorizeDragUpdate(Offset globalPos) {
    _overlayKey.currentState?.updateDrag(globalPos);
  }

  void _onCategorizeDragEnd(Offset globalPos) {
    _overlayKey.currentState?.endDrag(globalPos);
  }

  void _assignCategory(CategoryBase? category) {
    final todo = _categorizingTodo;
    if (todo == null) return;
    _repo.updateTodoCategory(todo.id, category?.id);
    _dismissCategorize();
  }

  void _dismissCategorize() {
    setState(() => _categorizingTodo = null);
  }

  /// Dropped on the overlay title instead of a category: moves the todo
  /// to the front of the list (and persists the new order) rather than
  /// categorizing it.
  void _moveCategorizingTodoToTop() {
    final todo = _categorizingTodo;
    if (todo == null) return;
    setState(() {
      _todos.removeWhere((t) => t.id == todo.id);
      _todos.insert(0, todo);
      _categorizingTodo = null;
    });
    _repo.reorderTodos(_todos.map((t) => t.id).toList());
  }

  Future<void> _editTodo(Todo todo) async {
    final newTitle = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _EditTodoScreen(initialTitle: todo.title),
      ),
    );
    _screenFocusNode.requestFocus();
    final title = newTitle?.trim();
    if (title == null || title.isEmpty || title == todo.title) return;
    // The repo change listener reloads the list.
    await _repo.updateTodoTitle(todo.id, title);
  }

  void _openEditCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EditCategoriesScreen(store: TodoCategoryStore())),
    );
    _loadAll();
    _screenFocusNode.requestFocus();
  }

  TodoCategory? _categoryForTodo(Todo todo) {
    if (todo.categoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == todo.categoryId);
    } catch (_) {
      return null;
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: Focus(
        focusNode: _screenFocusNode,
        autofocus: true,
        onKeyEvent: _handleScreenKeyEvent,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  if (_isAuthenticated && _searchVisible)
                    _buildSearchBar(),
                  Expanded(child: _buildContent()),
                ],
              ),
              if (_categorizingTodo != null) _buildCategorizeOverlay(),
            ],
          ),
        ),
      ),
      floatingActionButton:
          _isAuthenticated && !_isAdding && _categorizingTodo == null
              ? FloatingActionButton(
                  // Unique tag: the other tabs' FABs coexist in the
                  // IndexedStack and default hero tags would clash.
                  heroTag: 'todo_fab',
                  onPressed: _startAdding,
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Afazeres', style: AppTheme.headingLarge),
                const SizedBox(height: 4),
                Text(
                  _surpriseDescription,
                  style: AppTheme.bodyText
                      .copyWith(color: AppTheme.mediumBrown),
                ),
              ],
            ),
          ),
          if (_isAuthenticated) ...[
            IconButton(
              tooltip: 'Buscar',
              icon: Icon(
                Icons.search,
                color: _searchVisible
                    ? AppTheme.primaryOrange
                    : AppTheme.darkBrown,
              ),
              onPressed: _toggleSearch,
            ),
            const SyncIndicator(),
            const SizedBox(width: 4),
          ],
          if (_isAuthenticated)
            PopupMenuButton<String>(
              icon:
                  const Icon(Icons.more_vert, color: AppTheme.darkBrown),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
              color: AppTheme.white,
              onSelected: (value) {
                if (value == 'group') _toggleGroupByCategory();
                if (value == 'group_order') _openGroupOrderSheet();
                if (value == 'categories') _openEditCategories();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'group',
                  child: Row(
                    children: [
                      Icon(
                        _groupByCategory
                            ? Icons.layers_clear_outlined
                            : Icons.layers_outlined,
                        color: AppTheme.primaryOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(_groupByCategory
                          ? 'Desagrupar'
                          : 'Agrupar por categoria'),
                    ],
                  ),
                ),
                if (_groupByCategory)
                  const PopupMenuItem(
                    value: 'group_order',
                    child: Row(
                      children: [
                        Icon(Icons.swap_vert,
                            color: AppTheme.primaryOrange,
                            size: 20),
                        SizedBox(width: 12),
                        Text('Ordenar grupos'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined,
                          color: AppTheme.primaryOrange, size: 20),
                      SizedBox(width: 12),
                      Text('Editar Categorias'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_isAuthenticated) return _buildSignInPrompt();
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }
    if (_isAdding) return _buildAddingView();
    if (_todos.isEmpty) return _buildEmptyState();
    if (_searchVisible && _searchController.text.trim().isNotEmpty) {
      return _buildSearchResults();
    }
    if (_groupByCategory) return _buildGroupedList();
    return _buildTodoList();
  }

  Widget _buildSearchResults() {
    final visible = _visibleTodos;
    if (visible.isEmpty) return _buildNoSearchResults();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (final todo in visible) _buildGroupedItem(todo),
      ],
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64,
              color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Nenhuma tarefa encontrada',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Tente outro termo de busca',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: AppTheme.bodyText,
          decoration: InputDecoration(
            hintText: 'Buscar por tarefa ou categoria',
            hintStyle: TextStyle(
                color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.search,
                color: AppTheme.mediumBrown),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar',
                    icon: const Icon(Icons.close,
                        color: AppTheme.mediumBrown),
                    onPressed: () =>
                        setState(_searchController.clear),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    AppTheme.primaryOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  size: 48, color: AppTheme.primaryOrange),
            ),
            const SizedBox(height: 24),
            const Text('Faça login para ver seus afazeres',
                style: AppTheme.headingMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Vá para a aba Perfil para fazer login ou criar uma conta',
              style: AppTheme.bodyText
                  .copyWith(color: AppTheme.mediumBrown),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt,
              size: 64,
              color:
                  AppTheme.primaryOrange.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('All clear!', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Tap + to add a new task',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildAddingView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.softShadow,
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'O que precisa fazer?',
                hintStyle: TextStyle(
                    color: AppTheme.mediumBrown
                        .withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.add_task,
                    color: AppTheme.primaryOrange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      AppTheme.radiusMedium),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryOrange, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => _saveAndStopAdding(),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _saveAndStopAdding,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (_, child) => Material(
            color: Colors.transparent,
            elevation: 6,
            borderRadius:
                BorderRadius.circular(AppTheme.radiusMedium),
            child: child,
          ),
          child: child,
        );
      },
      onReorder: _onReorder,
      itemCount: _todos.length,
      itemBuilder: (context, index) {
        final todo = _todos[index];
        final cat = _categoryForTodo(todo);
        return _SwipeableTodoItem(
          key: ValueKey(todo.id),
          todo: todo,
          index: index,
          category: cat,
          hasCategories: _categories.isNotEmpty,
          onToggle: () => _toggleTodo(todo),
          onEdit: () => _editTodo(todo),
          onDelete: () => _deleteTodo(todo),
          onCategorizeStart: () => _startCategorize(todo),
          onCategorizeDragUpdate: _onCategorizeDragUpdate,
          onCategorizeDragEnd: _onCategorizeDragEnd,
        );
      },
    );
  }

  // --- Grouped view (visual only; stored order is untouched) ---

  Widget _buildGroupedList() {
    final byCategory = <String, List<Todo>>{};
    final uncategorized = <Todo>[];
    for (final todo in _todos) {
      if (todo.categoryId != null &&
          _categories.any((c) => c.id == todo.categoryId)) {
        byCategory.putIfAbsent(todo.categoryId!, () => []).add(todo);
      } else {
        uncategorized.add(todo);
      }
    }

    final children = <Widget>[];
    for (final key in _effectiveGroupOrder()) {
      if (key == _uncategorizedKey) {
        if (uncategorized.isNotEmpty) {
          children.add(_buildCategoryGroup(null, uncategorized));
        }
      } else if (byCategory.containsKey(key)) {
        children.add(_buildCategoryGroup(
          _categories.firstWhere((c) => c.id == key),
          byCategory[key]!,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: children,
    );
  }

  /// [cat] is null for the "Sem categoria" group.
  Widget _buildCategoryGroup(TodoCategory? cat, List<Todo> items) {
    final key = cat?.id ?? _uncategorizedKey;
    final color = cat?.color ?? AppTheme.mediumBrown;
    final collapsed = _collapsedGroups.contains(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: cat == null ? 0.05 : 0.08),
          borderRadius:
              BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
              color:
                  color.withValues(alpha: cat == null ? 0.2 : 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleGroupCollapsed(key),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 2, 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cat?.color ??
                            AppTheme.mediumBrown
                                .withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat?.name ?? 'Sem categoria',
                        style: AppTheme.caption.copyWith(
                            fontSize: 13,
                            color: AppTheme.darkBrown),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (collapsed) ...[
                      Text('${items.length}',
                          style: AppTheme.caption),
                      const SizedBox(width: 4),
                    ],
                    AnimatedRotation(
                      turns: collapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: AppTheme.mediumBrown
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: collapsed
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      children: [
                        // The tinted card already shows the category,
                        // so items skip their color stripe here.
                        for (final todo in items)
                          _buildGroupedItem(todo, inGroup: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupOrderSheet() {
    final order = _effectiveGroupOrder();

    String nameFor(String key) => key == _uncategorizedKey
        ? 'Sem categoria'
        : _categories.firstWhere((c) => c.id == key).name;
    Color colorFor(String key) => key == _uncategorizedKey
        ? AppTheme.mediumBrown.withValues(alpha: 0.4)
        : _categories.firstWhere((c) => c.id == key).color;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ordem dos grupos',
                      style: AppTheme.sectionTitle),
                  const SizedBox(height: 4),
                  const Text('Arraste para reordenar',
                      style: AppTheme.caption),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ReorderableListView(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        final item = order.removeAt(oldIndex);
                        order.insert(newIndex, item);
                        setSheetState(() {});
                        // Rebuilds the list behind the sheet too.
                        setState(
                            () => _groupOrder = List.of(order));
                        _saveGroupOrder();
                      },
                      children: [
                        for (int i = 0; i < order.length; i++)
                          ListTile(
                            key: ValueKey(order[i]),
                            dense: true,
                            leading: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: colorFor(order[i]),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              nameFor(order[i]),
                              style: const TextStyle(
                                color: AppTheme.darkBrown,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: i,
                              child: Icon(
                                Icons.drag_indicator,
                                color: AppTheme.mediumBrown
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupedItem(Todo todo, {bool inGroup = false}) {
    return _SwipeableTodoItem(
      key: ValueKey(todo.id),
      todo: todo,
      index: 0,
      category: inGroup ? null : _categoryForTodo(todo),
      hasCategories: _categories.isNotEmpty,
      canReorder: false,
      onToggle: () => _toggleTodo(todo),
      onEdit: () => _editTodo(todo),
      onDelete: () => _deleteTodo(todo),
      onCategorizeStart: () => _startCategorize(todo),
      onCategorizeDragUpdate: _onCategorizeDragUpdate,
      onCategorizeDragEnd: _onCategorizeDragEnd,
    );
  }

  // --- Categorize overlay ---

  Widget _buildCategorizeOverlay() {
    return CategorizeOverlay(
      key: _overlayKey,
      categories: _categories,
      itemLabel: _categorizingTodo?.title ?? '',
      onAssign: _assignCategory,
      onDismiss: _dismissCategorize,
      onMoveToTop: _moveCategorizingTodoToTop,
    );
  }
}

// ---------------------------------------------------------------------------
// Swipeable todo item with drag handle, left-delete, right-categorize
// ---------------------------------------------------------------------------

class _SwipeableTodoItem extends StatelessWidget {
  final Todo todo;
  final int index;
  final TodoCategory? category;
  final bool hasCategories;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCategorizeStart;
  final ValueChanged<Offset> onCategorizeDragUpdate;
  final ValueChanged<Offset> onCategorizeDragEnd;
  final bool canReorder;

  const _SwipeableTodoItem({
    super.key,
    required this.todo,
    required this.index,
    required this.category,
    required this.hasCategories,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onCategorizeStart,
    required this.onCategorizeDragUpdate,
    required this.onCategorizeDragEnd,
    this.canReorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return SwipeActionCard(
      canCategorize: hasCategories,
      onDelete: onDelete,
      onCategorizeStart: onCategorizeStart,
      onCategorizeDragUpdate: onCategorizeDragUpdate,
      onCategorizeDragEnd: onCategorizeDragEnd,
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final cat = category;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius:
              BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (cat != null)
                Container(width: 4, color: cat.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  // Stack rather than a plain Row so the drag handle
                  // (a Positioned with top/bottom pinned) can stretch to
                  // match whatever height the checkbox+title row ends up
                  // needing, without that height being decided in a
                  // circular way (Positioned children are ignored for
                  // intrinsic-size purposes, unlike a Row child would be).
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          // Checkbox
                          GestureDetector(
                            onTap: onToggle,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: todo.isCompleted
                                    ? AppTheme.primaryOrange
                                    : AppTheme.primaryOrange
                                        .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: todo.isCompleted
                                    ? null
                                    : Border.all(
                                        color: AppTheme.borderOrange,
                                        width: 2),
                              ),
                              child: todo.isCompleted
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title (tap to edit). Rendered as markdown so
                          // multi-line tasks blend together in the card
                          // instead of looking like a single truncated
                          // line. Right padding reserves room for the
                          // drag handle overlaid on top.
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: canReorder ? 30 : 0),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onEdit,
                                child: MarkdownBody(
                                  data: todo.title,
                                  selectable: false,
                                  softLineBreak: true,
                                  styleSheet: _todoMarkdownStyleSheet(
                                    context,
                                    TextStyle(
                                      fontSize: 16,
                                      color: todo.isCompleted
                                          ? AppTheme.mediumBrown
                                          : AppTheme.darkBrown,
                                      decoration: todo.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Drag handle (manual order only applies to the
                      // ungrouped list). Invisible by design — it still
                      // grabs drags, it just doesn't draw dots over the
                      // title — and pinned top-to-bottom so a multi-line
                      // task can be grabbed from any line, not just the
                      // vertical center.
                      if (canReorder)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: ReorderableDragStartListener(
                            index: index,
                            child: SizedBox(
                              width: 30,
                              child: Center(
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: Colors.transparent,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Markdown styling shared by the card preview and the fullscreen editor
// ---------------------------------------------------------------------------

/// Builds on the theme defaults (so paddings/decorations the package
/// expects are never null) and overrides just the bits that need to match
/// [base] — the same style the plain-text title used to render with.
MarkdownStyleSheet _todoMarkdownStyleSheet(
    BuildContext context, TextStyle base) {
  final strikethrough = TextDecoration.combine(
      [base.decoration ?? TextDecoration.none, TextDecoration.lineThrough]);
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: base,
    a: base,
    listBullet: base,
    blockSpacing: 4,
    listIndent: 20,
    pPadding: EdgeInsets.zero,
    checkbox: base.copyWith(color: AppTheme.primaryOrange),
    strong: base.copyWith(fontWeight: FontWeight.bold),
    em: base.copyWith(fontStyle: FontStyle.italic),
    del: base.copyWith(decoration: strikethrough),
    blockquote: base.copyWith(fontStyle: FontStyle.italic),
    code: base.copyWith(
      fontFamily: 'monospace',
      fontSize: (base.fontSize ?? 16) - 1,
      backgroundColor: AppTheme.lightPeach,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fullscreen markdown editor for a todo's title
// ---------------------------------------------------------------------------

/// Fullscreen editor for a todo's title. Unlike the single-line quick-add
/// field, Return inserts a newline here instead of submitting — the text is
/// still stored as plain markdown in the `title` column; only editing and
/// rendering understand it. Pops with the new text, or null when cancelled.
class _EditTodoScreen extends StatefulWidget {
  final String initialTitle;

  const _EditTodoScreen({required this.initialTitle});

  @override
  State<_EditTodoScreen> createState() => _EditTodoScreenState();
}

class _EditTodoScreenState extends State<_EditTodoScreen> {
  static const _baseStyle = TextStyle(
    fontSize: 16,
    color: AppTheme.darkBrown,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  late final TextEditingController _controller;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Wraps the current selection in [marker] (or inserts an empty pair at
  /// the cursor when nothing is selected), e.g. `**` for bold.
  void _wrapSelection(String marker) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final selected = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$marker$selected$marker');
    _controller.value = TextEditingValue(
      text: newText,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + marker.length)
          : TextSelection(
              baseOffset: start,
              extentOffset: start + marker.length * 2 + selected.length),
    );
  }

  /// Inserts [prefix] at the start of the line the cursor is on, e.g.
  /// `- ` for a bullet or `- [ ] ` for a checklist item.
  void _insertLinePrefix(String prefix) {
    final text = _controller.text;
    final sel = _controller.selection;
    final offset = sel.start < 0 ? text.length : sel.start;
    final lineStart =
        offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        elevation: 0,
        foregroundColor: AppTheme.darkBrown,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Editar tarefa'),
        actions: [
          IconButton(
            icon: Icon(_showPreview
                ? Icons.edit_outlined
                : Icons.visibility_outlined),
            tooltip: _showPreview ? 'Editar' : 'Visualizar',
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text(
              'Salvar',
              style: TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _showPreview
              ? SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: MarkdownBody(
                      data: _controller.text.trim().isEmpty
                          ? '_Nada para mostrar_'
                          : _controller.text,
                      selectable: false,
                      softLineBreak: true,
                      styleSheet:
                          _todoMarkdownStyleSheet(context, _baseStyle),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _EditorToolbarButton(
                          icon: Icons.format_bold,
                          tooltip: 'Negrito',
                          onPressed: () => _wrapSelection('**'),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.format_italic,
                          tooltip: 'Itálico',
                          onPressed: () => _wrapSelection('*'),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.format_list_bulleted,
                          tooltip: 'Lista',
                          onPressed: () => _insertLinePrefix('- '),
                        ),
                        _EditorToolbarButton(
                          icon: Icons.check_box_outlined,
                          tooltip: 'Checklist',
                          onPressed: () => _insertLinePrefix('- [ ] '),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          style: _baseStyle,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EditorToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _EditorToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.mediumBrown),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
        ),
      ),
    );
  }
}
