import 'sleep_event.dart';

/// A closed sleep interval, assigned to the day whose 18:00-to-18:00
/// window it falls in (i.e. from [day]-1 18:00 to [day] 18:00).
class SleepInterval {
  final DateTime day;
  final double startHour; // hours since the window start (0..24)
  final double endHour;
  final Duration duration;

  SleepInterval(this.day, this.startHour, this.endHour, this.duration);
}

/// Hours from the sleep moment to the following midnight-anchored day
/// boundary: with an 18:00 cutover, that's 24h - 18h = 6h. A nap any time
/// before evening lands in the window that opened the previous evening and
/// closes at 18:00 today, so it's assigned to *today*; sleep starting at
/// 18:00 or later falls in the window that closes at 18:00 tomorrow, so a
/// bedtime is assigned to the morning it ends, same as before.
const _dayCutoverShift = Duration(hours: 6);

/// Pairs each sleep event with the next wake event and assigns the
/// interval to the day its 18:00-to-18:00 window ends on.
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
      final bucket = sleep.add(_dayCutoverShift);
      final day = DateTime(bucket.year, bucket.month, bucket.day);
      final windowStart = day.subtract(_dayCutoverShift); // D-1 18:00
      final start = sleep.difference(windowStart).inMinutes / 60.0;
      final end =
          (wake.difference(windowStart).inMinutes / 60.0).clamp(0.0, 24.0);
      intervals.add(SleepInterval(day, start.clamp(0.0, 24.0), end, duration));
    }
  }
  return intervals;
}
