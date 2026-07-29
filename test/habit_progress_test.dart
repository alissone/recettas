import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/habit.dart';
import 'package:recettas/widgets/habit_calendar.dart';

Habit _habit({
  HabitGoalType goalType = HabitGoalType.counter,
  double goalTarget = 1,
  String? goalUnit,
  HabitPeriod period = HabitPeriod.daily,
}) {
  return Habit(
    id: 'h1',
    userId: 'u1',
    name: 'Beber água',
    goalType: goalType,
    goalTarget: goalTarget,
    goalUnit: goalUnit,
    period: period,
  );
}

HabitLog _log(String date, double value) => HabitLog(
      id: '$date-$value',
      userId: 'u1',
      habitId: 'h1',
      logDate: date,
      value: value,
    );

void main() {
  group('daysInMonth', () {
    test('handles 30, 31 and leap-year February', () {
      expect(daysInMonth(DateTime(2026, 7, 15)), 31);
      expect(daysInMonth(DateTime(2026, 4, 1)), 30);
      expect(daysInMonth(DateTime(2026, 2, 10)), 28);
      expect(daysInMonth(DateTime(2024, 2, 10)), 29);
    });
  });

  group('dailyTarget', () {
    test('daily goals use the target as-is', () {
      final habit = _habit(goalTarget: 8);
      expect(habit.dailyTarget(DateTime(2026, 7, 29)), 8);
    });

    test('weekly goals spread evenly over seven days', () {
      final habit = _habit(goalTarget: 14, period: HabitPeriod.weekly);
      expect(habit.dailyTarget(DateTime(2026, 7, 29)), 2);
    });

    test('monthly goals spread over the length of that month', () {
      final habit = _habit(goalTarget: 31, period: HabitPeriod.monthly);
      expect(habit.dailyTarget(DateTime(2026, 7, 10)), 1);
      // February is shorter, so each day carries more.
      expect(habit.dailyTarget(DateTime(2026, 2, 10)),
          closeTo(31 / 28, 1e-9));
    });
  });

  group('period boundaries', () {
    test('daily periods are a single day', () {
      final habit = _habit();
      final day = DateTime(2026, 7, 29);
      expect(habit.periodStart(day), day);
      expect(habit.periodEnd(day), DateTime(2026, 7, 30));
    });

    test('weekly periods start on Monday and span seven days', () {
      final habit = _habit(period: HabitPeriod.weekly);
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2026, 7, 27).add(Duration(days: i));
        final start = habit.periodStart(day);
        expect(start.weekday, DateTime.monday);
        expect(start.isAfter(day), isFalse);
        expect(habit.periodEnd(day).difference(start).inDays, 7);
      }
    });

    test('monthly periods run from the 1st to the next 1st', () {
      final habit = _habit(period: HabitPeriod.monthly);
      final day = DateTime(2026, 12, 20);
      expect(habit.periodStart(day), DateTime(2026, 12, 1));
      expect(habit.periodEnd(day), DateTime(2027, 1, 1));
    });
  });

  group('formatValue', () {
    test('durations read as hours and minutes', () {
      final habit = _habit(goalType: HabitGoalType.duration);
      expect(habit.formatValue(45), '45min');
      expect(habit.formatValue(90), '1h30');
      expect(habit.formatValue(120), '2h');
      expect(habit.formatValue(0), '0min');
    });

    test('counters use the custom unit, falling back to "vezes"', () {
      expect(_habit(goalUnit: 'copos').formatValue(8), '8 copos');
      expect(_habit().formatValue(3), '3 vezes');
      expect(_habit(goalUnit: 'páginas').formatValue(2.5),
          '2.5 páginas');
    });

    test('duration goals ignore any counter unit label', () {
      final habit = _habit(
          goalType: HabitGoalType.duration, goalUnit: 'copos');
      expect(habit.unitLabel, 'min');
    });
  });

  group('sumLogsByDay', () {
    test('adds every log that shares a day', () {
      final totals = sumLogsByDay([
        _log('2026-07-29', 15),
        _log('2026-07-29', 20),
        _log('2026-07-28', 5),
      ]);
      expect(totals[DateTime(2026, 7, 29)], 35);
      expect(totals[DateTime(2026, 7, 28)], 5);
      expect(totals[DateTime(2026, 7, 27)], isNull);
    });

    test('ignores rows with an unparseable date', () {
      final totals = sumLogsByDay([_log('não é data', 5)]);
      expect(totals, isEmpty);
    });
  });

  group('HabitCalendar layout', () {
    test('leading blanks put the 1st under its weekday, Monday first',
        () {
      // 2026-06-01 is a Monday: no blanks.
      expect(HabitCalendar.leadingBlanks(DateTime(2026, 6, 15)), 0);
      // 2026-07-01 is a Wednesday: two blanks.
      expect(HabitCalendar.leadingBlanks(DateTime(2026, 7, 15)), 2);
    });

    test('row count covers every day of the month', () {
      for (var month = 1; month <= 12; month++) {
        final day = DateTime(2026, month, 1);
        final rows = HabitCalendar.rowsFor(day);
        expect(rows * 7,
            greaterThanOrEqualTo(
                HabitCalendar.leadingBlanks(day) + daysInMonth(day)),
            reason: 'month $month does not fit in $rows rows');
        expect(rows, inInclusiveRange(4, 6));
      }
    });

    test('cells tile the available width exactly', () {
      const width = 350.0;
      final cell = HabitCalendar.cellSize(width);
      expect(cell * 7 + HabitCalendar.cellSpacing * 6,
          closeTo(width, 1e-9));
    });
  });
}
