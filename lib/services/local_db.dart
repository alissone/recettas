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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            category_id TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
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
        await db.execute(_createGpsRecordingsSql);
        await db.execute(_createGpsPointsSql);
        await db.execute(_createGpsPointsIndexSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE todos ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute(_createGpsRecordingsSql);
          await db.execute(_createGpsPointsSql);
          await db.execute(_createGpsPointsIndexSql);
        }
      },
    );
    return _db!;
  }

  static const _createGpsRecordingsSql = '''
    CREATE TABLE gps_recordings (
      id TEXT PRIMARY KEY,
      started_at TEXT NOT NULL,
      ended_at TEXT,
      interval_seconds INTEGER NOT NULL,
      distance_meters REAL NOT NULL DEFAULT 0,
      point_count INTEGER NOT NULL DEFAULT 0,
      preview_points TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  static const _createGpsPointsSql = '''
    CREATE TABLE gps_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recording_id TEXT NOT NULL,
      sequence INTEGER NOT NULL,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      altitude REAL,
      timestamp TEXT NOT NULL
    )
  ''';

  static const _createGpsPointsIndexSql =
      'CREATE INDEX idx_gps_points_recording_id ON gps_points(recording_id)';
}
