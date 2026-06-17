import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/todo.dart';
import '../services/supabase_service.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<Todo> _todos = [];
  bool _isLoading = true;
  bool _isAdding = false;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadTodos();

    _authSubscription =
        SupabaseService.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {});
        _loadTodos();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isAuthenticated => SupabaseService.currentUser != null;

  Future<void> _loadTodos() async {
    if (!_isAuthenticated) {
      if (mounted) {
        setState(() {
          _todos = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      if (mounted) setState(() => _isLoading = true);
      final todos = await SupabaseService.getTodos();
      if (mounted) {
        setState(() {
          _todos = todos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTodo() async {
    final title = _textController.text.trim();
    if (title.isEmpty) return;

    _textController.clear();
    await SupabaseService.addTodo(title);
    _loadTodos();
  }

  Future<void> _toggleTodo(Todo todo) async {
    await SupabaseService.toggleTodo(todo.id, !todo.isCompleted);
    _loadTodos();
  }

  Future<void> _deleteTodo(Todo todo) async {
    await SupabaseService.deleteTodo(todo.id);
    _loadTodos();
  }

  void _startAdding() {
    setState(() => _isAdding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _saveAndStopAdding() {
    final title = _textController.text.trim();
    if (title.isNotEmpty) {
      _addTodo();
    }
    _textController.clear();
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('To-Do', style: AppTheme.headingLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Keep track of your tasks',
                style: AppTheme.bodyText
                    .copyWith(color: AppTheme.mediumBrown),
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton:
          _isAuthenticated && !_isAdding
              ? FloatingActionButton(
                  onPressed: _startAdding,
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }

  Widget _buildContent() {
    if (!_isAuthenticated) {
      return _buildSignInPrompt();
    }

    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }

    if (_isAdding) {
      return _buildAddingView();
    }

    if (_todos.isEmpty) {
      return _buildEmptyState();
    }

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
    return RefreshIndicator(
      onRefresh: _loadTodos,
      color: AppTheme.primaryOrange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _todos.length,
        itemBuilder: (context, index) =>
            _buildTodoItem(_todos[index]),
      ),
    );
  }

  Widget _buildTodoItem(Todo todo) {
    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteTodo(todo),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius:
              BorderRadius.circular(AppTheme.radiusMedium),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child:
            const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius:
              BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          leading: GestureDetector(
            onTap: () => _toggleTodo(todo),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: todo.isCompleted
                    ? AppTheme.primaryOrange
                    : AppTheme.primaryOrange
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
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
          title: Text(
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
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      ),
    );
  }
}
