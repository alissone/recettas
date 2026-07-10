import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../models/todo_category.dart';
import '../services/category_store.dart';
import '../services/supabase_service.dart';
import '../services/todo_repository.dart';
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
  String _surpriseDescription = _surpriseDescriptions[
      Random().nextInt(_surpriseDescriptions.length)];
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription? _authSubscription;

  // Categorize overlay state
  Todo? _categorizingTodo;
  int? _highlightedIndex;
  List<GlobalKey> _squircleKeys = [];

  TodoRepository get _repo => TodoRepository.instance;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadGroupPrefs();

    // New surprise description whenever the user switches tabs. The screen
    // stays alive in the IndexedStack, so initState alone isn't enough.
    homeTabIndex.addListener(_pickSurpriseDescription);

    // Reload whenever the local cache changes (own writes or background
    // sync pulling fresh data from the server).
    _repo.onChange.addListener(_loadAll);

    _authSubscription =
        SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {});
        _loadAll();
      }
    });
  }

  @override
  void dispose() {
    homeTabIndex.removeListener(_pickSurpriseDescription);
    _repo.onChange.removeListener(_loadAll);
    _authSubscription?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _pickSurpriseDescription() {
    if (!mounted) return;
    setState(() {
      _surpriseDescription = _surpriseDescriptions[
          Random().nextInt(_surpriseDescriptions.length)];
    });
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
          _updateSquircleKeys();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSquircleKeys() {
    // +1 for "No category" option
    _squircleKeys = List.generate(
      _categories.length + 1,
      (_) => GlobalKey(),
    );
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
  }

  // --- Categorize overlay ---

  void _startCategorize(Todo todo) {
    if (_categories.isEmpty) return;
    setState(() => _categorizingTodo = todo);
  }

  void _onCategorizeDragUpdate(Offset globalPos) {
    setState(() {
      _highlightedIndex = _hitTestSquircles(globalPos);
    });
  }

  void _onCategorizeDragEnd(Offset globalPos) {
    final idx = _hitTestSquircles(globalPos);
    if (idx != null) {
      _assignCategory(idx);
    } else {
      _dismissCategorize();
    }
  }

  int? _hitTestSquircles(Offset globalPos) {
    for (int i = 0; i < _squircleKeys.length; i++) {
      final box = _squircleKeys[i].currentContext?.findRenderObject()
          as RenderBox?;
      if (box != null && box.attached) {
        final local = box.globalToLocal(globalPos);
        if (box.paintBounds.contains(local)) return i;
      }
    }
    return null;
  }

  void _assignCategory(int index) {
    final todo = _categorizingTodo;
    if (todo == null) return;

    String? categoryId;
    if (index < _categories.length) {
      categoryId = _categories[index].id;
    }
    // index == _categories.length means "No category"

    _repo.updateTodoCategory(todo.id, categoryId);
    setState(() {
      _categorizingTodo = null;
      _highlightedIndex = null;
    });
  }

  void _dismissCategorize() {
    setState(() {
      _categorizingTodo = null;
      _highlightedIndex = null;
    });
  }

  void _openEditCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              EditCategoriesScreen(store: TodoCategoryStore())),
    );
    _loadAll();
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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
            if (_categorizingTodo != null) _buildCategorizeOverlay(),
          ],
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
    if (_groupByCategory) return _buildGroupedList();
    return _buildTodoList();
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
          onDelete: () => _deleteTodo(todo),
          onCategorizeStart: () => _startCategorize(todo),
          onCategorizeDragUpdate: _onCategorizeDragUpdate,
          onCategorizeDragEnd: _onCategorizeDragEnd,
          isCategorizing: _categorizingTodo?.id == todo.id,
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
      onDelete: () => _deleteTodo(todo),
      onCategorizeStart: () => _startCategorize(todo),
      onCategorizeDragUpdate: _onCategorizeDragUpdate,
      onCategorizeDragEnd: _onCategorizeDragEnd,
      isCategorizing: _categorizingTodo?.id == todo.id,
    );
  }

  // --- Categorize overlay ---

  Widget _buildCategorizeOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _dismissCategorize,
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            color: AppTheme.darkBrown.withValues(alpha: 0.7),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Arraste pra uma categoria',
                    style: AppTheme.headingMedium
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _categorizingTodo?.title ?? '',
                    style: AppTheme.bodyText
                        .copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        for (int i = 0; i < _categories.length; i++)
                          _buildSquircle(
                            key: _squircleKeys[i],
                            color: _categories[i].color,
                            label: _categories[i].name,
                            highlighted: _highlightedIndex == i,
                            onTap: () => _assignCategory(i),
                          ),
                        _buildSquircle(
                          key: _squircleKeys.last,
                          color: AppTheme.mediumBrown
                              .withValues(alpha: 0.4),
                          label: 'Nenhuma',
                          icon: Icons.close,
                          highlighted: _highlightedIndex ==
                              _categories.length,
                          onTap: () =>
                              _assignCategory(_categories.length),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Solte para cancelar',
                    style: AppTheme.caption
                        .copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquircle({
    required GlobalKey key,
    required Color color,
    required String label,
    bool highlighted = false,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: highlighted ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: key,
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                border: highlighted
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: Colors.white, size: 28)
                    : Text(
                        label.isNotEmpty
                            ? label[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipeable todo item with drag handle, left-delete, right-categorize
// ---------------------------------------------------------------------------

class _SwipeableTodoItem extends StatefulWidget {
  final Todo todo;
  final int index;
  final TodoCategory? category;
  final bool hasCategories;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onCategorizeStart;
  final ValueChanged<Offset> onCategorizeDragUpdate;
  final ValueChanged<Offset> onCategorizeDragEnd;
  final bool isCategorizing;
  final bool canReorder;

  const _SwipeableTodoItem({
    super.key,
    required this.todo,
    required this.index,
    required this.category,
    required this.hasCategories,
    required this.onToggle,
    required this.onDelete,
    required this.onCategorizeStart,
    required this.onCategorizeDragUpdate,
    required this.onCategorizeDragEnd,
    required this.isCategorizing,
    this.canReorder = true,
  });

  @override
  State<_SwipeableTodoItem> createState() => _SwipeableTodoItemState();
}

class _SwipeableTodoItemState extends State<_SwipeableTodoItem>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _categorizeTriggered = false;
  Offset _lastGlobalPos = Offset.zero;
  late AnimationController _springController;
  late Animation<double> _springAnim;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _springAnim = _springController.drive(Tween(begin: 0.0, end: 0.0));
    _springController.addListener(() {
      setState(() => _dragOffset = _springAnim.value);
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _springBack() {
    _springAnim = Tween(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(
          parent: _springController, curve: Curves.easeOut),
    );
    _springController.forward(from: 0);
  }

  void _onDragStart(DragStartDetails d) {
    _springController.stop();
    _categorizeTriggered = false;
    _dragOffset = 0;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _lastGlobalPos = d.globalPosition;

    if (_categorizeTriggered) {
      widget.onCategorizeDragUpdate(d.globalPosition);
      return;
    }

    setState(() {
      _dragOffset += d.delta.dx;
      _dragOffset = _dragOffset.clamp(-160.0, 160.0);
    });

    if (_dragOffset > 80 && !_categorizeTriggered && widget.hasCategories) {
      _categorizeTriggered = true;
      _springBack();
      widget.onCategorizeStart();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_categorizeTriggered) {
      widget.onCategorizeDragEnd(_lastGlobalPos);
      _categorizeTriggered = false;
      return;
    }

    if (_dragOffset < -100) {
      widget.onDelete();
    }
    _springBack();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // Delete background (right swipe → left side)
          if (_dragOffset < 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 24),
              ),
            ),
          // Categorize hint background (left swipe → right side)
          if (_dragOffset > 0 && widget.hasCategories)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange
                      .withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Icon(Icons.category_outlined,
                    color: AppTheme.primaryOrange, size: 24),
              ),
            ),
          // Card
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: GestureDetector(
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: _buildCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final todo = widget.todo;
    final cat = widget.category;

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
                  child: Row(
                    children: [
                      // Checkbox
                      GestureDetector(
                        onTap: widget.onToggle,
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
                      // Title
                      Expanded(
                        child: Text(
                          todo.title,
                          style: TextStyle(
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
                      const SizedBox(width: 4),
                      // Drag handle (manual order only applies to the
                      // ungrouped list)
                      if (widget.canReorder)
                        ReorderableDragStartListener(
                          index: widget.index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            child: Icon(
                              Icons.drag_indicator,
                              color: AppTheme.mediumBrown
                                  .withValues(alpha: 0.3),
                              size: 22,
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
