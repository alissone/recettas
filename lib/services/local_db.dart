import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Local SQLite cache. Todos and categories are mirrored here so the UI
/// reads/writes instantly and offline; pending_ops holds writes that
/// still need to be pushed to Supabase.
class LocalDb {
  LocalDb._();

  static Database? _db;

  /// Must run before any db access. Desktop platforms need the ffi
  /// factory instead of the mobile plugin.
  static void initPlatform() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
  }

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'recettas_cache.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            category_id TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE todo_categories (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            color_value INTEGER NOT NULL,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_ops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
