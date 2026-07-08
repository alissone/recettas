import 'sleep_event.dart';

/// A closed sleep interval, assigned to the night that ends on [day]
/// (i.e. the noon-to-noon window from [day]-1 12:00 to [day] 12:00).
class SleepInterval {
  final DateTime day;
  final double startHour; // hours since the window start (0..24)
  final double endHour;
  final Duration duration;

  SleepInterval(this.day, this.startHour, this.endHour, this.duration);
}

/// Pairs each sleep event with the next wake event and assigns the
/// interval to the day the window ends on (sleep time + 12h).
List<SleepInterval> buildSleepIntervals(List<SleepEvent> events) {
  final sorted = List<SleepEvent>.of(events)
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  final intervals = <SleepInterval>[];
  DateTime? pendingSleep;
  for (final event in sorted) {
    if (event.isSleep) {
      // Consecutive sleep events: keep the most recent one.
      pendingSleep = event.occurredAt;
    } else if (pendingSleep != null) {
      final sleep = pendingSleep;
      final wake = event.occurredAt;
      pendingSleep = null;
      final duration = wake.difference(sleep);
      if (duration <= Duration.zero || duration > const Duration(hours: 24)) {
        continue; // bad pair (clock issues / forgotten log)
      }
      final bucket = sleep.add(const Duration(hours: 12));
      final day = DateTime(bucket.year, bucket.month, bucket.day);
      final windowStart = day.subtract(const Duration(hours: 12)); // D-1 12:00
      final start = sleep.difference(windowStart).inMinutes / 60.0;
      final end =
          (wake.difference(windowStart).inMinutes / 60.0).clamp(0.0, 24.0);
      intervals.add(SleepInterval(day, start.clamp(0.0, 24.0), end, duration));
    }
  }
  return intervals;
}
