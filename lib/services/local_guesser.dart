import 'package:geolocator/geolocator.dart';

import '../widgets/local_field.dart';

/// Guesses which frequent place the user is at by comparing the current
/// GPS position against the coordinates in [kFrequentLocalCoords].
class LocalGuesser {
  LocalGuesser._();

  /// The closest frequent place within [kLocalSuggestionRadiusMeters],
  /// or null when none is near, location is off/denied or the fix
  /// times out — callers just skip the suggestion in that case.
  static Future<String?> guess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return nearestWithin(position.latitude, position.longitude);
    } catch (_) {
      // No GPS fix or unsupported platform: silently don't suggest.
      return null;
    }
  }

  /// The frequent place closest to ([lat], [lng]), or null when none is
  /// within [kLocalSuggestionRadiusMeters]. When several places are in
  /// range the nearest one wins.
  static String? nearestWithin(double lat, double lng) {
    String? best;
    var bestDistance = double.infinity;
    for (final entry in kFrequentLocalCoords.entries) {
      final coords = parseCoords(entry.value);
      if (coords == null) continue;
      final distance =
          Geolocator.distanceBetween(lat, lng, coords.$1, coords.$2);
      if (distance <= kLocalSuggestionRadiusMeters &&
          distance < bestDistance) {
        bestDistance = distance;
        best = entry.key;
      }
    }
    return best;
  }

  /// Parses a "lat, lng" string; null when malformed.
  static (double, double)? parseCoords(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }
}
