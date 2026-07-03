import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';
import '../models/todo_category.dart';
import 'local_db.dart';

enum SyncState {
  /// Local cache matches the server.
  synced,

  /// Pushing local changes and/or pulling fresh data.
  syncing,

  /// Server unreachable; changes are queued locally and will retry.
  offline,
}

/// Offline-first store for todos and their categories.
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
    sync();
  }

  void _bump() => _revision.value++;

  // --- Reads (local cache, instant) ---

  Future<List<Todo>> getTodos() async {
    final uid = _userId;
    if (uid == null) return [];
    final db = await LocalDb.instance;
    final rows = await db.query(
      'todos',
      where: 'user_id = ?',
      whereArgs: [uid],
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return rows.map(Todo.fromDb).toList();
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

  // --- Todo writes (optimistic: local first, then queued push) ---

  Future<void> addTodo(String title) async {
    final uid = _userId;
    if (uid == null) return;
    final todo = Todo(
      id: _uuid.v4(),
      userId: uid,
      title: title,
      createdAt: DateTime.now().toUtc(),
    );
    final db = await LocalDb.instance;
    await db.insert('todos', todo.toDb());
    await _enqueue('todo_insert', {
      'id': todo.id,
      'user_id': uid,
      'title': title,
    });
  }

  Future<void> toggleTodo(String id, bool isCompleted) async {
    final db = await LocalDb.instance;
    await db.update(
      'todos',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueue('todo_update', {
      'id': id,
      'fields': {'is_completed': isCompleted},
    });
  }

  Future<void> deleteTodo(String id) async {
    final db = await LocalDb.instance;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
    await _enqueue('todo_delete', {'id': id});
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
      case 'todo_reorder':
        final ids = (p['ids'] as List).cast<String>();
        await Future.wait(ids.asMap().entries.map((e) => _client
            .from('todos')
            .update({'sort_order': e.key}).eq('id', e.value)));
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

    final todosData = await _client
        .from('todos')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    final catsData =
        await _client.from('todo_categories').select().order('created_at');

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
      batch.delete('todos', where: 'user_id = ?', whereArgs: [uid]);
      for (final json in todosData) {
        batch.insert('todos', Todo.fromJson(json).toDb());
      }
      batch.delete('todo_categories', where: 'user_id = ?', whereArgs: [uid]);
      for (final json in catsData) {
        batch.insert('todo_categories', TodoCategory.fromJson(json).toDb());
      }
      await batch.commit(noResult: true);
    });
    _bump();
  }

  Future<void> _clearLocal() async {
    final db = await LocalDb.instance;
    await db.delete('todos');
    await db.delete('todo_categories');
    await db.delete('pending_ops');
    syncState.value = SyncState.synced;
    _bump();
  }
}
