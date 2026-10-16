import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/utility_reading.dart';
import 'package:recettas/services/utility_usage.dart';

UtilityReading r(double value, DateTime at) => UtilityReading(
    id: '$value', kind: UtilityKind.energy, value: value, recordedAt: at);

void main() {
  final now = DateTime(2026, 10, 15, 12);

  test('only a baseline reading means zero usage and no forecast', () {
    final u = UtilityUsage.compute([r(4003, DateTime(2026, 10, 3))], now)!;
    expect(u.usedSoFar, 0);
    expect(u.projected, isNull);
    expect(u.prevSoFar, isNull);
  });

  test('usage is the difference from the first reading', () {
    final u = UtilityUsage.compute([
      r(4003, DateTime(2026, 10, 1)),
      r(4009, DateTime(2026, 10, 5)),
    ], now)!;
    expect(u.usedSoFar, closeTo(6, 1e-9));
  });

  test('forecast follows a steady rate to month end', () {
    // 2 kWh/day from Oct 1 00:00 to Oct 11 00:00.
    final u = UtilityUsage.compute([
      r(1000, DateTime(2026, 10, 1)),
      r(1010, DateTime(2026, 10, 6)),
      r(1020, DateTime(2026, 10, 11)),
    ], DateTime(2026, 10, 11))!;
    expect(u.usedSoFar, closeTo(20, 1e-9));
    expect(u.projected, closeTo(62, 1e-6)); // 31 days * 2
  });

  test('compares with the previous month at the same point', () {
    // 1 kWh/day through September, 2 kWh/day in October.
    final u = UtilityUsage.compute([
      r(100, DateTime(2026, 9, 1)),
      r(130, DateTime(2026, 10, 1)),
      r(140, DateTime(2026, 10, 6)),
    ], DateTime(2026, 10, 6))!;
    expect(u.usedSoFar, closeTo(10, 1e-9));
    expect(u.prevSoFar, closeTo(5, 1e-9));
    expect(u.changeVsPrev, closeTo(1.0, 1e-9));
    expect(u.prevTotal, closeTo(30, 1e-9));
  });

  test('a reading gap straddling the month boundary is split by time', () {
    final u = UtilityUsage.compute([
      r(0, DateTime(2026, 9, 30)),
      r(20, DateTime(2026, 10, 2)),
    ], DateTime(2026, 10, 2))!;
    expect(u.usedSoFar, closeTo(10, 1e-9)); // only Oct 1-2 of the 2-day gap
  });
}
