import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../models/todo_category.dart';
import '../services/category_store.dart';
import '../services/supabase_service.dart';
import '../services/todo_repository.dart';
import '../widgets/sync_indicator.dart';
import 'edit_categories_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<Todo> _todos = [];
  List<TodoCategory> _categories = [];
  bool _isLoading = true;
  bool _isAdding = false;
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
    _repo.onChange.removeListener(_loadAll);
    _authSubscription?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
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
    await _repo.deleteTodo(todo.id);
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
                  // Unique tag: the Compras FAB coexists in the
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
                  'Monitore suas tarefas',
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
                if (value == 'categories') _openEditCategories();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined,
                          color: AppTheme.primaryOrange, size: 20),
                      SizedBox(width: 12),
                      Text('Edit Categories'),
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
            const Text('Sign in to manage tasks',
                style: AppTheme.headingMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Go to the Profile tab to sign in or create an account',
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
                hintText: 'What needs to be done?',
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
                    'Drag to a category',
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
                          label: 'None',
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
                    'Release to cancel',
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
                                    color: AppTheme.primaryOrange
                                        .withValues(alpha: 0.3),
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
                      // Drag handle
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
