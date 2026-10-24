import '../models/utility_reading.dart';

/// A point on the usage chart: [x] is days since the start of the month,
/// [y] the usage accumulated by then.
class UsagePoint {
  final double x;
  final double y;
  const UsagePoint(this.x, this.y);
}

/// Month-to-date usage of one meter, its forecast for the rest of the
/// month, and the same stretch of the previous month for comparison.
///
/// Readings are cumulative meter values, so usage over any period is the
/// meter at its end minus the meter at its start. Between two readings the
/// meter is assumed to advance at a constant rate, which lets a month
/// boundary that falls between readings be split fairly.
class UtilityUsage {
  final DateTime monthStart;
  final DateTime nextMonthStart;

  /// The instant the figures are measured up to: the latest reading, or
  /// now when that reading is from an earlier month.
  final DateTime asOf;

  /// Month-to-date usage, including [estimatedBefore].
  final double usedSoFar;

  /// When the first reading came after the month began, the usage between
  /// the month start and that reading, estimated at the month's rate so the
  /// month still adds up to a whole one. Zero otherwise.
  final double estimatedBefore;

  /// Usage over the 24 hours ending at [last24hEnd] (the latest reading),
  /// interpolated between readings - or scaled from the overall rate when
  /// the readings span less than a day. Null with fewer than two readings.
  final double? last24h;
  final DateTime last24hEnd;

  /// Expected usage for the whole month; null until there is enough
  /// history to estimate a rate.
  final double? projected;

  /// Previous month up to the same day and time. Null when the first
  /// reading came after that month began, since the figure would be
  /// partial.
  final double? prevSoFar;
  final double? prevTotal;

  final List<UsagePoint> current;
  final List<UsagePoint> previous;
  final List<UsagePoint> forecast;

  /// The estimated stretch from the month start to the first reading;
  /// empty when there is none.
  final List<UsagePoint> backfill;

  const UtilityUsage({
    required this.monthStart,
    required this.nextMonthStart,
    required this.asOf,
    required this.usedSoFar,
    required this.estimatedBefore,
    required this.last24h,
    required this.last24hEnd,
    required this.projected,
    required this.prevSoFar,
    required this.prevTotal,
    required this.current,
    required this.previous,
    required this.forecast,
    required this.backfill,
  });

  int get daysInMonth => nextMonthStart.difference(monthStart).inDays;

  /// Where the estimated stretch ends: the first reading. Only meaningful
  /// when [backfill] is not empty.
  DateTime get backfillEnd => backfill.isEmpty
      ? monthStart
      : monthStart.add(Duration(
          milliseconds:
              (backfill.last.x * Duration.millisecondsPerDay).round()));

  /// Change against the previous month at the same point, as a fraction
  /// (0.12 = 12% more). Null when there is nothing to compare against.
  double? get changeVsPrev {
    final prev = prevSoFar;
    if (prev == null || prev <= 0) return null;
    return (usedSoFar - prev) / prev;
  }

  /// Meter value at [t], interpolated between the surrounding readings and
  /// held flat outside the recorded range. [sorted] must be oldest first.
  static double meterAt(List<UtilityReading> sorted, DateTime t) {
    if (!t.isAfter(sorted.first.recordedAt)) return sorted.first.value;
    if (!t.isBefore(sorted.last.recordedAt)) return sorted.last.value;
    for (var i = 1; i < sorted.length; i++) {
      final b = sorted[i];
      if (t.isAfter(b.recordedAt)) continue;
      final a = sorted[i - 1];
      final span = b.recordedAt.difference(a.recordedAt).inMilliseconds;
      if (span <= 0) return b.value;
      final f = t.difference(a.recordedAt).inMilliseconds / span;
      return a.value + (b.value - a.value) * f;
    }
    return sorted.last.value;
  }

  static double _days(Duration d) => d.inMilliseconds / Duration.millisecondsPerDay;

  /// Null when there are no readings at all.
  static UtilityUsage? compute(List<UtilityReading> readings, DateTime now) {
    if (readings.isEmpty) return null;
    final sorted = [...readings]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final first = sorted.first.recordedAt;
    final last = sorted.last.recordedAt;

    final monthStart = DateTime(now.year, now.month);
    final nextStart = DateTime(now.year, now.month + 1);
    final prevStart = DateTime(now.year, now.month - 1);
    final daysInPrev = monthStart.difference(prevStart).inDays;

    final asOf = (last.isAfter(monthStart) && !last.isAfter(now)) ? last : now;
    final meterAtMonthStart = meterAt(sorted, monthStart);

    // --- Rate: least-squares line through this month's readings ---
    final fit = <UsagePoint>[
      if (!first.isAfter(monthStart)) UsagePoint(0, 0),
      for (final r in sorted)
        if (!r.recordedAt.isBefore(monthStart))
          UsagePoint(_days(r.recordedAt.difference(monthStart)),
              r.value - meterAtMonthStart),
    ];
    double? slope = _slope(fit);
    if (slope == null) {
      // Fewer than two readings this month: fall back to the trailing
      // 30 days of history.
      final window = last.subtract(const Duration(days: 30));
      final from = window.isBefore(first) ? first : window;
      final days = _days(last.difference(from));
      if (days > 0) {
        slope = (sorted.last.value - meterAt(sorted, from)) / days;
      }
    }
    if (slope != null && slope < 0) slope = 0;

    // --- Before the first reading: same rate, back to the month start ---
    final firstX = first.isAfter(monthStart)
        ? _days(first.difference(monthStart))
        : 0.0;
    final estimatedBefore = slope == null ? 0.0 : slope * firstX;
    final usedSoFar =
        meterAt(sorted, asOf) - meterAtMonthStart + estimatedBefore;

    // --- Last 24h, ending at the latest reading ---
    final dayAgo = last.subtract(const Duration(days: 1));
    final spanDays = _days(last.difference(first));
    final double? last24h = spanDays <= 0
        ? null
        : first.isAfter(dayAgo)
            ? (sorted.last.value - sorted.first.value) / spanDays
            : sorted.last.value - meterAt(sorted, dayAgo);

    // --- Previous month, same point in time ---
    final prevAsOf = DateTime(
      prevStart.year,
      prevStart.month,
      asOf.day > daysInPrev ? daysInPrev : asOf.day,
      asOf.hour,
      asOf.minute,
    );
    final hasPrev = !first.isAfter(prevStart);
    final meterAtPrevStart = meterAt(sorted, prevStart);
    final prevSoFar = hasPrev && !last.isBefore(prevAsOf)
        ? meterAt(sorted, prevAsOf) - meterAtPrevStart
        : null;
    final prevTotal = hasPrev && !last.isBefore(monthStart)
        ? meterAtMonthStart - meterAtPrevStart
        : null;

    final remainingDays = _days(nextStart.difference(asOf));
    final projected =
        slope == null ? null : usedSoFar + slope * remainingDays;

    // --- Chart series ---
    final current = <UsagePoint>[
      if (!first.isAfter(monthStart)) const UsagePoint(0, 0),
      for (final r in sorted)
        if (r.recordedAt.isAfter(monthStart) &&
            !r.recordedAt.isAfter(nextStart))
          UsagePoint(_days(r.recordedAt.difference(monthStart)),
              r.value - meterAtMonthStart + estimatedBefore),
    ];
    final backfill = firstX > 0 && slope != null
        ? [const UsagePoint(0, 0), UsagePoint(firstX, estimatedBefore)]
        : <UsagePoint>[];

    final previous = <UsagePoint>[];
    if (hasPrev) {
      for (var i = 0; i <= daysInPrev; i++) {
        final t = DateTime(prevStart.year, prevStart.month, 1 + i);
        if (t.isAfter(last)) break;
        previous.add(UsagePoint(i.toDouble(), meterAt(sorted, t) - meterAtPrevStart));
      }
    }

    final daysInMonth = nextStart.difference(monthStart).inDays;
    final forecast = projected == null
        ? <UsagePoint>[]
        : [
            UsagePoint(_days(asOf.difference(monthStart)), usedSoFar),
            UsagePoint(daysInMonth.toDouble(), projected),
          ];

    return UtilityUsage(
      monthStart: monthStart,
      nextMonthStart: nextStart,
      asOf: asOf,
      usedSoFar: usedSoFar,
      estimatedBefore: estimatedBefore,
      last24h: last24h,
      last24hEnd: last,
      projected: projected,
      prevSoFar: prevSoFar,
      prevTotal: prevTotal,
      current: current,
      previous: previous,
      forecast: forecast,
      backfill: backfill,
    );
  }

  /// Slope of the least-squares line, or null with fewer than two
  /// distinct x values.
  static double? _slope(List<UsagePoint> pts) {
    if (pts.length < 2) return null;
    final n = pts.length;
    final meanX = pts.fold<double>(0, (s, p) => s + p.x) / n;
    final meanY = pts.fold<double>(0, (s, p) => s + p.y) / n;
    var cov = 0.0, varX = 0.0;
    for (final p in pts) {
      cov += (p.x - meanX) * (p.y - meanY);
      varX += (p.x - meanX) * (p.x - meanX);
    }
    if (varX <= 1e-9) return null;
    return cov / varX;
  }
}
