import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../app_theme.dart';
import '../models/todo.dart';
import '../models/todo_card.dart';
import '../models/todo_category.dart';
import '../services/supabase_service.dart';
import 'web_common.dart';

/// Web "Afazeres": the open todos in their manual order. Add, tick,
/// archive and drag to reorder; completed todos are never fetched (one
/// ticked in this session stays visible, struck through, until reload).
/// Cards render read-only - editing and categorizing stay in the app.
class WebTodoScreen extends StatefulWidget {
  const WebTodoScreen({super.key});

  @override
  State<WebTodoScreen> createState() => _WebTodoScreenState();
}

class _WebTodoScreenState extends State<WebTodoScreen> {
  List<Todo> _todos = [];
  Map<String, TodoCategory> _categories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.getOpenTodos(),
        SupabaseService.getTodoCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _todos = results[0] as List<Todo>;
        _categories = {
          for (final c in results[1] as List<TodoCategory>) c.id: c,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showWebError(context, e);
    }
  }

  /// Runs a write; on failure shows the error and reloads so the list
  /// matches the server again.
  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      showWebError(context, e);
      _load();
    }
  }

  Future<void> _add(String title) => _write(() async {
        final todo = await SupabaseService.addTodo(title);
        // New rows get sort_order 0, which the app also puts on top.
        if (mounted) setState(() => _todos.insert(0, todo));
      });

  Future<void> _toggle(Todo todo) {
    final done = !todo.isCompleted;
    final completedAt = done ? DateTime.now().toUtc() : null;
    _replace(todo, isCompleted: done, completedAt: completedAt);
    return _write(() => SupabaseService.updateTodo(todo.id, {
          'is_completed': done,
          'completed_at': completedAt?.toIso8601String(),
        }));
  }

  /// Like the app, "deleting" only archives the row.
  Future<void> _archive(Todo todo) {
    setState(() => _todos.removeWhere((t) => t.id == todo.id));
    return _write(
        () => SupabaseService.updateTodo(todo.id, {'is_archived': true}));
  }

  void _replace(Todo old, {required bool isCompleted, DateTime? completedAt}) {
    final i = _todos.indexWhere((t) => t.id == old.id);
    if (i < 0) return;
    setState(() {
      _todos[i] = Todo(
        id: old.id,
        userId: old.userId,
        title: old.title,
        isCompleted: isCompleted,
        categoryId: old.categoryId,
        sortOrder: old.sortOrder,
        isArchived: old.isArchived,
        createdAt: old.createdAt,
        completedAt: completedAt,
      );
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() => _todos.insert(newIndex, _todos.removeAt(oldIndex)));
    _write(() => SupabaseService.reorderTodos(_todos.map((t) => t.id).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final open = _todos.where((t) => !t.isCompleted).length;
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: WebPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebHeader(
                title: 'Afazeres',
                subtitle: open == 0
                    ? 'Nada pendente'
                    : open == 1
                        ? '1 tarefa pendente'
                        : '$open tarefas pendentes',
                actions: [
                  IconButton(
                    tooltip: 'Atualizar',
                    icon: const Icon(Icons.refresh, color: AppTheme.darkBrown),
                    onPressed: _load,
                  ),
                ],
              ),
              QuickAddField(
                hint: 'Nova tarefa',
                icon: Icons.add_task,
                onSubmit: _add,
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return webSpinner;
    if (_todos.isEmpty) {
      return const WebEmptyState(
        icon: Icons.check_circle_outline,
        title: 'Nenhuma tarefa',
        subtitle: 'Digite acima para adicionar uma',
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: child,
      ),
      onReorderItem: _onReorder,
      itemCount: _todos.length,
      itemBuilder: (context, index) {
        final todo = _todos[index];
        return Padding(
          key: ValueKey(todo.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: WebCard(
            stripe: _categories[todo.categoryId]?.color,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: WebCheckbox(
                    checked: todo.isCompleted,
                    onTap: () => _toggle(todo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _TodoContent(
                      card: TodoCard.parse(todo.title),
                      completed: todo.isCompleted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Arquivar',
                  icon: Icon(Icons.delete_outline,
                      color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
                  onPressed: () => _archive(todo),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.drag_indicator,
                          color: AppTheme.mediumBrown.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Read-only rendering of a todo's text: markdown for plain todos, a
/// one-line header (places / date) above the body for the other kinds.
class _TodoContent extends StatelessWidget {
  final TodoCard card;
  final bool completed;

  const _TodoContent({required this.card, required this.completed});

  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  static const _months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  TextStyle get _style => TextStyle(
        fontSize: 16,
        color: completed ? AppTheme.mediumBrown : AppTheme.darkBrown,
        decoration: completed ? TextDecoration.lineThrough : null,
        fontWeight: FontWeight.w500,
      );

  String? get _header {
    switch (card.kind) {
      case TodoKind.todo:
        return null;
      case TodoKind.move:
        return card.summary;
      case TodoKind.event:
        final date = card.date;
        final start = card.start;
        final end = card.end;
        return [
          if (date != null)
            '${_weekdays[date.weekday - 1]}, ${date.day} '
                '${_months[date.month - 1]}',
          if (start != null)
            end != null
                ? '${TodoCard.formatTime(start)}–${TodoCard.formatTime(end)}'
                : TodoCard.formatTime(start),
          if (card.eventTitle.isNotEmpty) card.eventTitle,
        ].join(' · ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _header;
    final body = card.body.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Row(
            children: [
              Icon(card.kind.icon, size: 18, color: AppTheme.primaryOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(header,
                    style: _style.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        if (header != null && body.isNotEmpty) const SizedBox(height: 4),
        if (body.isNotEmpty)
          MarkdownBody(
            data: body,
            softLineBreak: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
              p: _style,
              a: _style,
              listBullet: _style,
              blockSpacing: 4,
              listIndent: 20,
              pPadding: EdgeInsets.zero,
              checkbox: _style.copyWith(color: AppTheme.primaryOrange),
            ),
          ),
      ],
    );
  }
}
