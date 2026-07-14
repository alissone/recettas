import 'dart:convert';

import 'gps_point.dart';

/// Summary of one GPS recording session. Full-resolution points live in
/// the gps_points table and are only loaded on demand (detail view,
/// GPX export); [previewPoints] is a small downsampled track kept
/// alongside the summary so history cards can draw a thumbnail without
/// an extra query per card.
class GpsRecording {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int intervalSeconds;
  final double distanceMeters;
  final int pointCount;
  final List<GpsLatLng> previewPoints;

  const GpsRecording({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.intervalSeconds,
    this.distanceMeters = 0,
    this.pointCount = 0,
    this.previewPoints = const [],
  });

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  factory GpsRecording.fromDb(Map<String, dynamic> row) {
    final rawPreview = row['preview_points'] as String?;
    final preview = <GpsLatLng>[];
    if (rawPreview != null && rawPreview.isNotEmpty) {
      final decoded = jsonDecode(rawPreview) as List;
      for (final entry in decoded) {
        final m = entry as Map<String, dynamic>;
        preview.add(
            GpsLatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()));
      }
    }
    return GpsRecording(
      id: row['id'] as String,
      startedAt: DateTime.parse(row['started_at'] as String),
      endedAt: row['ended_at'] != null
          ? DateTime.parse(row['ended_at'] as String)
          : null,
      intervalSeconds: row['interval_seconds'] as int,
      distanceMeters: (row['distance_meters'] as num?)?.toDouble() ?? 0,
      pointCount: row['point_count'] as int? ?? 0,
      previewPoints: preview,
    );
  }
}
