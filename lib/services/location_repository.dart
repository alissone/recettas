import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/gps_point.dart';
import '../models/gps_recording.dart';
import 'local_db.dart';

/// Local-only store for GPS recordings. Unlike [TodoRepository] there is
/// no Supabase sync: recordings stay on-device until the user exports
/// them as GPX.
class LocationRepository {
  LocationRepository._();

  static final LocationRepository instance = LocationRepository._();

  static const _uuid = Uuid();

  /// Thumbnails on history cards are drawn from a downsampled copy of
  /// the track kept on the summary row, capped at this many points.
  static const _maxPreviewPoints = 40;

  Future<String> startRecording(int intervalSeconds) async {
    final db = await LocalDb.instance;
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.insert('gps_recordings', {
      'id': id,
      'started_at': now.toIso8601String(),
      'ended_at': null,
      'interval_seconds': intervalSeconds,
      'distance_meters': 0.0,
      'point_count': 0,
      'preview_points': null,
      'created_at': now.toIso8601String(),
    });
    return id;
  }

  Future<void> addPoint(String recordingId, int sequence, GpsPoint point) async {
    final db = await LocalDb.instance;
    await db.insert('gps_points', {
      'recording_id': recordingId,
      'sequence': sequence,
      'lat': point.lat,
      'lng': point.lng,
      'altitude': point.altitude,
      'timestamp': point.timestamp.toIso8601String(),
    });
  }

  Future<void> finishRecording(
    String recordingId, {
    required DateTime endedAt,
    required double distanceMeters,
    required List<GpsPoint> points,
  }) async {
    final db = await LocalDb.instance;
    final preview = _downsample(points, _maxPreviewPoints)
        .map((p) => {'lat': p.lat, 'lng': p.lng})
        .toList();
    await db.update(
      'gps_recordings',
      {
        'ended_at': endedAt.toIso8601String(),
        'distance_meters': distanceMeters,
        'point_count': points.length,
        'preview_points': jsonEncode(preview),
      },
      where: 'id = ?',
      whereArgs: [recordingId],
    );
  }

  Future<List<GpsRecording>> getRecordings() async {
    final db = await LocalDb.instance;
    final rows = await db.query(
      'gps_recordings',
      where: 'ended_at IS NOT NULL',
      orderBy: 'started_at DESC',
    );
    return rows.map(GpsRecording.fromDb).toList();
  }

  Future<List<GpsPoint>> getPoints(String recordingId) async {
    final db = await LocalDb.instance;
    final rows = await db.query(
      'gps_points',
      where: 'recording_id = ?',
      whereArgs: [recordingId],
      orderBy: 'sequence ASC',
    );
    return rows.map(GpsPoint.fromDb).toList();
  }

  Future<void> deleteRecording(String recordingId) async {
    final db = await LocalDb.instance;
    await db
        .delete('gps_points', where: 'recording_id = ?', whereArgs: [recordingId]);
    await db.delete('gps_recordings', where: 'id = ?', whereArgs: [recordingId]);
  }

  /// Drops recordings left over from a session that was killed mid-run
  /// (no [Timer] survives an app kill, so they can never be resumed).
  Future<void> cleanupIncomplete() async {
    final db = await LocalDb.instance;
    final rows = await db
        .query('gps_recordings', columns: ['id'], where: 'ended_at IS NULL');
    for (final row in rows) {
      await deleteRecording(row['id'] as String);
    }
  }

  List<GpsPoint> _downsample(List<GpsPoint> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    final step = points.length / maxPoints;
    return [for (var i = 0; i < maxPoints; i++) points[(i * step).floor()]];
  }
}
