/// A single GPS fix captured during a recording.
class GpsPoint {
  final double lat;
  final double lng;
  final double? altitude;
  final DateTime timestamp;

  const GpsPoint({
    required this.lat,
    required this.lng,
    this.altitude,
    required this.timestamp,
  });

  factory GpsPoint.fromDb(Map<String, dynamic> row) => GpsPoint(
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        altitude:
            row['altitude'] != null ? (row['altitude'] as num).toDouble() : null,
        timestamp: DateTime.parse(row['timestamp'] as String),
      );
}

/// Bare coordinate pair used for route thumbnails, which only need
/// lat/lng to draw the track — no altitude or timestamp.
class GpsLatLng {
  final double lat;
  final double lng;

  const GpsLatLng(this.lat, this.lng);
}
