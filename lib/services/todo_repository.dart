import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/contact.dart';
import '../models/todo.dart';
import '../models/todo_category.dart';
import '../models/todo_daily.dart';
import '../models/todo_tags.dart';
import 'local_db.dart';

enum SyncState {
  /// Local cache matches the server.
  synced,

  /// Pushing local changes and/or pulling fresh data.
  syncing,

  /// Server unreachable; changes are queued locally and will retry.
  offline,
}

/// Offline-first store for todos, their categories and the contacts
/// ("Pessoas") that "@" tags resolve against.
///
/// All reads and writes hit the local SQLite cache first, so the UI is
/// instant and works with no connection. Every write is also queued in
/// pending_ops and pushed to Supabase in the background (FIFO). Once the
/// queue drains, the cache is refreshed from the server.
class TodoRepository {
  TodoRepository._();

  static final TodoRepository instance = TodoRepository._();

  static const _uuid = Uuid();
  static const _retryDelay = Duration(seconds: 12);

  /// Drives the little sync indicator in the header.
  final ValueNotifier<SyncState> syncState = ValueNotifier(SyncState.synced);

  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// Fires whenever cached data changes (local write or server pull).
  Listenable get onChange => _revision;

  bool _syncing = false;
  bool _syncAgain = false;
  Timer? _retryTimer;
  Timer? _dailyTimer;
  AppLifecycleListener? _lifecycle;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<void> init() async {
    await LocalDb.instance;
    _client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          sync();
        case AuthChangeEvent.signedOut:
          _clearLocal();
        default:
          break;
      }
    });
    // Todos other people tag you on only arrive with a pull, so coming
    // back to the app is a good moment for one.
    _lifecycle ??= AppLifecycleListener(onResume: sync);
    sync();
  }

  void _bump() => _revision.value++;

  // --- Reads (local cache, instant) ---

  /// Own todos plus the ones someone else tagged this user on.
  static const _visibleWhere = '(user_id = ? OR assignee_ids LIKE ?) AND '
      'is_archived = 0';

  /// Front matter line of repeating (daily/monthly) todos (see TodoDaily).
  static const _dailyLike = '%repeat: %';

  Future<List<Todo>> getTodos() async {
    final uid = _userId;
    if (uid == null) return [];
    await _rolloverDaily(uid);
    final db = await LocalDb.instance;
    final rows = await db.query(
      'todos',
      // Completed todos from a previous day stay in the database (and on
      // the server) but drop out of the list once the day has passed;
      // legacy rows with no completed_at (completed before this existed)
      // count as "old" too. Daily ones are read regardless, since a
      // rollover may be pending: TodoDaily.isListed has the last word.
      where: '$_visibleWhere AND '
          '(is_completed = 0 OR title LIKE ? OR (completed_at IS NOT NULL '
          "AND strftime('%s', completed_at) >= strftime('%s', ?)))",
      whereArgs: [
        uid,
        '%"$uid"%',
        _dailyLike,
        _startOfTodayUtc().toIso8601String(),
      ],
      // Completed items sink to the bottom of the list; todos pinned with
      // "@today" float to the top until the day is over, then fall back
      // to their manual position. todayKey() is a generated YYYY-MM-DD.
      orderBy: 'is_completed ASC, '
          "COALESCE(today_on = '${TodoTags.todayKey()}', 0) DESC, "
          'sort_order ASC, created_at DESC',
    );
    final todos = rows.map(Todo.fromDb).toList();
    _scheduleDailyRefresh(todos);
    return todos.where(TodoDaily.isListed).toList();
  }

  /// Brings "@daily" todos whose time has come back to today (unticked,
  /// pinned on top), locally and on the server.
  Future<void> _rolloverDaily(String uid) async {
    final db = await LocalDb.instance;
    final rows = await db.query(
      'todos',
      where: '$_visibleWhere AND title LIKE ?',
      whereArgs: [uid, '%"$uid"%', _dailyLike],
    );
    var rolled = false;
    for (final todo in rows.map(Todo.fromDb)) {
      final fields = TodoDaily.rollover(todo);
      if (fields == null) continue;
      await db.update(
        'todos',
        {...fields, 'is_completed': 0},
        where: 'id = ?',
        whereArgs: [todo.id],
      );
      // Straight into the queue: going through _enqueue would bump and
      // re-enter getTodos for every row.
      await db.insert('pending_ops', {
        'type': 'todo_update',
        'payload': jsonEncode({'id': todo.id, 'fields': fields}),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      rolled = true;
    }
    if (rolled) sync();
  }

  /// Reloads the list when the next "@daily" todo is due today, so it pops
  /// back up at its time even if nothing else happens.
  void _scheduleDailyRefresh(List<Todo> todos) {
    _dailyTimer?.cancel();
    final next = TodoDaily.nextRollover(todos);
    if (next == null) return;
    _dailyTimer = Timer(next.difference(DateTime.now()), _bump);
  }

  /// Midnight in the device's local timezone, expressed in UTC — the
  /// cutoff below which a completed todo counts as "from a previous day".
  DateTime _startOfTodayUtc() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toUtc();
  }

  Future<List<TodoCategory>> getCategories() async {
    final uid = _userId;
    if (uid == null) return [];
    final db = await LocalDb.instance;
    final rows = await db.query(
      'todo_categories',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'created_at ASC',
    );
    return rows.map(TodoCategory.fromDb).toList();
  }

  Future<List<Contact>> getContacts() async {
    final uid = _userId;
    if (uid == null) return [];
    final db = await LocalDb.instance;
    final rows = await db.query(
      'contacts',
      where: 'owner_id = ?',
      whereArgs: [uid],
      orderBy: 'nickname COLLATE NOCASE ASC',
    );
    return rows.map(Contact.fromDb).toList();
  }

  // --- Todo writes (optimistic: local first, then queued push) ---

  /// [text] may carry "@" tags: "@today" pins the todo for the day and
  /// "@nickname" shares it with that contact (see [TodoTags]).
  Future<void> addTodo(String text) async {
    final uid = _userId;
    if (uid == null) return;
    final title = _applyDaily(TodoTags.stripToday(text));
    if (title.isEmpty) return;
    final todo = Todo(
      id: _uuid.v4(),
      userId: uid,
      title: title,
      createdAt: DateTime.now().toUtc(),
      assigneeIds: TodoTags.assigneeIds(title, await getContacts()),
      todayOn: TodoTags.hasToday(text) || TodoTags.hasDaily(text)
          ? TodoTags.todayKey()
          : null,
    );
    final db = await LocalDb.instance;
    await db.insert('todos', todo.toDb());
    await _enqueue('todo_insert', {
      'id': todo.id,
      'user_id': uid,
      'title': title,
      'assignee_ids': todo.assigneeIds,
      'today_on': todo.todayOn,
    });
  }

  /// Saves the editor's text. Unlike [updateTodoTitle], the "@today" tag
  /// is authoritative here: the editor shows it on todos pinned for today
  /// (see [TodoTags.withToday]), so its absence unpins. Assignees follow
  /// the tags too, but only on the owner's side — it's their contacts.
  Future<void> editTodo(Todo todo, String text) async {
    final title = _applyDaily(TodoTags.stripToday(text));
    if (title.isEmpty) return;
    final assigneeIds = todo.userId == _userId
        ? TodoTags.assigneeIds(title, await getContacts())
        : null;
    final todayOn = TodoTags.hasToday(text) || TodoTags.hasDaily(text)
        ? TodoTags.todayKey()
        : null;
    final db = await LocalDb.instance;
    await db.update(
      'todos',
      {
        'title': title,
        'today_on': todayOn,
        if (assigneeIds != null) 'assignee_ids': jsonEncode(assigneeIds),
      },
      where: 'id = ?',
      whereArgs: [todo.id],
    );
    await _enqueue('todo_update', {
      'id': todo.id,
      'fields': {
        'title': title,
        'today_on': todayOn,
        if (assigneeIds != null) 'assignee_ids': assigneeIds,
      },
    });
  }

  Future<void> toggleTodo(String id, bool isCompleted) async {
    // Recorded so completed todos can be dropped from the list (and from
    // future fetches) once the day they were completed on has passed.
    final completedAt =
        isCompleted ? DateTime.now().toUtc().toIso8601String() : null;
    final db = await LocalDb.instance;
    await db.update(
      'todos',
      {'is_completed': isCompleted ? 1 : 0, 'completed_at': completedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueue('todo_update', {
      'id': id,
      'fields': {'is_completed': isCompleted, 'completed_at': completedAt},
    });
  }

  /// "@daily" in [text] makes it a daily event (see TodoDaily.toDaily).
  String _applyDaily(String text) {
    if (!TodoTags.hasDaily(text)) return text;
    final rest = TodoTags.stripDaily(text);
    return rest.isEmpty ? '' : TodoDaily.toDaily(rest);
  }

  /// "Deleting" from the UI only archives: the row stays in the database
  /// (local and server) but disappears from the list. On a todo someone
  /// else tagged this user on, it removes the tag instead — the owner
  /// keeps the todo.
  Future<void> archiveTodo(Todo todo) async {
    final db = await LocalDb.instance;
    if (todo.userId != _userId) {
      await db.delete('todos', where: 'id = ?', whereArgs: [todo.id]);
      await _enqueue('todo_leave', {'id': todo.id});
      return;
    }
    await db.update(
      'todos',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [todo.id],
    );
    await _enqueue('todo_update', {
      'id': todo.id,
      'fields': {'is_archived': true},
    });
  }

  Future<void> updateTodoTitle(String id, String title) async {
    final db = await LocalDb.instance;
    await db.update(
      'todos',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueue('todo_update', {
      'id': id,
      'fields': {'title': title},
    });
  }

  Future<void> updateTodoCategory(String todoId, String? categoryId) async {
    final db = await LocalDb.instance;
    await db.update(
      'todos',
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [todoId],
    );
    await _enqueue('todo_update', {
      'id': todoId,
      'fields': {'category_id': categoryId},
    });
  }

  Future<void> reorderTodos(List<String> todoIds) async {
    final db = await LocalDb.instance;
    final batch = db.batch();
    for (var i = 0; i < todoIds.length; i++) {
      batch.update(
        'todos',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [todoIds[i]],
      );
    }
    // Only the latest ordering matters; drop older queued reorders.
    batch.delete('pending_ops', where: 'type = ?', whereArgs: ['todo_reorder']);
    await batch.commit(noResult: true);
    await _enqueue('todo_reorder', {'ids': todoIds});
  }

  // --- Category writes ---

  Future<void> addCategory(String name, int colorValue) async {
    final uid = _userId;
    if (uid == null) return;
    final cat = TodoCategory(
      id: _uuid.v4(),
      userId: uid,
      name: name,
      colorValue: colorValue,
      createdAt: DateTime.now().toUtc(),
    );
    final db = await LocalDb.instance;
    await db.insert('todo_categories', cat.toDb());
    await _enqueue('cat_insert', {
      'id': cat.id,
      'user_id': uid,
      'name': name,
      'color_value': colorValue,
    });
  }

  Future<void> updateCategory(String id,
      {String? name, int? colorValue}) async {
    final fields = <String, dynamic>{};
    if (name != null) fields['name'] = name;
    if (colorValue != null) fields['color_value'] = colorValue;
    if (fields.isEmpty) return;
    final db = await LocalDb.instance;
    await db.update('todo_categories', fields,
        where: 'id = ?', whereArgs: [id]);
    await _enqueue('cat_update', {'id': id, 'fields': fields});
  }

  Future<void> deleteCategory(String id) async {
    final db = await LocalDb.instance;
    await db.delete('todo_categories', where: 'id = ?', whereArgs: [id]);
    // Mirror the server's "on delete set null" on todos.category_id.
    await db.update(
      'todos',
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    await _enqueue('cat_delete', {'id': id});
  }

  // --- Sync engine ---

  Future<void> _enqueue(String type, Map<String, dynamic> payload) async {
    final db = await LocalDb.instance;
    await db.insert('pending_ops', {
      'type': type,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    _bump();
    sync();
  }

  /// Push pending ops, then pull fresh data. Safe to call at any time.
  Future<void> sync() async {
    if (_userId == null) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    _retryTimer?.cancel();
    syncState.value = SyncState.syncing;
    try {
      final drained = await _drainOps();
      if (drained) {
        await _pull();
        syncState.value = SyncState.synced;
      }
    } catch (_) {
      _scheduleRetry();
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        sync();
      }
    }
  }

  void _scheduleRetry() {
    syncState.value = SyncState.offline;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, sync);
  }

  /// Returns true when the queue is empty; false when it stopped early
  /// because the server is unreachable (a retry is already scheduled).
  Future<bool> _drainOps() async {
    final db = await LocalDb.instance;
    while (true) {
      final rows = await db.query('pending_ops', orderBy: 'id ASC', limit: 1);
      if (rows.isEmpty) return true;
      final op = rows.first;
      try {
        await _execOp(op['type'] as String,
            jsonDecode(op['payload'] as String) as Map<String, dynamic>);
      } on PostgrestException {
        // The server rejected this op (bad data, RLS, already gone...).
        // Retrying would never succeed, so drop it; the pull afterwards
        // restores the server's view of that row.
      } catch (_) {
        _scheduleRetry();
        return false;
      }
      await db.delete('pending_ops', where: 'id = ?', whereArgs: [op['id']]);
    }
  }

  Future<void> _execOp(String type, Map<String, dynamic> p) async {
    switch (type) {
      case 'todo_insert':
        await _client.from('todos').insert(p);
      case 'todo_update':
        await _client.from('todos').update(p['fields']).eq('id', p['id']);
      case 'todo_delete':
        await _client.from('todos').delete().eq('id', p['id']);
      case 'todo_leave':
        await _client.rpc('leave_todo', params: {'todo_id': p['id']});
      case 'todo_reorder':
        // One call for the whole list (migration 040).
        await _client.rpc('reorder_todos', params: {'ids': p['ids']});
      case 'cat_insert':
        await _client.from('todo_categories').insert(p);
      case 'cat_update':
        await _client
            .from('todo_categories')
            .update(p['fields'])
            .eq('id', p['id']);
      case 'cat_delete':
        await _client.from('todo_categories').delete().eq('id', p['id']);
    }
  }

  Future<void> _pull() async {
    final uid = _userId;
    if (uid == null) return;

    // Archived (deleted) todos and completed-and-old ones are neither shown
    // nor needed locally, so skip pulling them down at all rather than
    // fetching and then filtering. Archived rows only ever grow, so this
    // keeps the pull proportional to the live list.
    final cutoff = _startOfTodayUtc().toIso8601String();
    final results = await Future.wait([
      _client
          .from('todos')
          .select()
          .eq('is_archived', false)
          // ...except repeating ones, which come back (see TodoDaily).
          // Loose match; getTodos filters precisely.
          .or('is_completed.eq.false,completed_at.gte.$cutoff,'
              'title.like.*daily*,title.like.*monthly*'),
      _client.from('todo_categories').select().order('created_at'),
      _client.from('contacts').select(),
    ]);
    final [todosData, catsData, contactsData] = results;

    final db = await LocalDb.instance;
    // New local writes may have arrived while we were fetching; applying
    // this snapshot would wipe them. Skip — the queued sync runs again.
    final pending = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM pending_ops')) ??
        0;
    if (pending > 0) {
      _syncAgain = true;
      return;
    }

    await db.transaction((txn) async {
      final batch = txn.batch();
      // Not just this user's rows: shared todos belong to someone else.
      batch.delete('todos');
      for (final json in todosData) {
        batch.insert('todos', Todo.fromJson(json).toDb());
      }
      batch.delete('todo_categories', where: 'user_id = ?', whereArgs: [uid]);
      for (final json in catsData) {
        batch.insert('todo_categories', TodoCategory.fromJson(json).toDb());
      }
      batch.delete('contacts');
      for (final json in contactsData) {
        batch.insert('contacts', Contact.fromJson(json).toDb());
      }
      await batch.commit(noResult: true);
    });
    _bump();
  }

  Future<void> _clearLocal() async {
    final db = await LocalDb.instance;
    await db.delete('todos');
    await db.delete('todo_categories');
    await db.delete('contacts');
    await db.delete('pending_ops');
    syncState.value = SyncState.synced;
    _bump();
  }
}
