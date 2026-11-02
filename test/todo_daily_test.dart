import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/todo.dart';
import 'package:recettas/models/todo_card.dart';
import 'package:recettas/models/todo_daily.dart';
import 'package:recettas/models/todo_tags.dart';

Todo _todo(String title, {bool done = false, DateTime? completedAt}) => Todo(
      id: 't1',
      userId: 'me',
      title: title,
      isCompleted: done,
      completedAt: completedAt,
    );

void main() {
  final nov1 = DateTime(2026, 11, 1, 20, 0);
  final daily = TodoDaily.toDaily('Regar as plantas\nas da varanda', nov1);

  test('toDaily turns a plain todo into a 09:00 daily event', () {
    final card = TodoCard.parse(daily);
    expect(card.isDaily, isTrue);
    expect(card.eventTitle, 'Regar as plantas');
    expect(card.body, 'as da varanda');
    expect(card.meta['date'], '2026-11-01');
    expect(card.meta['start'], '09:00');
  });

  test('toDaily keeps an existing event\'s date and time', () {
    final card = TodoCard.parse(TodoDaily.toDaily(
        '---\ntype: event\ntitle: Ração\ndate: 2026-11-03\nstart: 07:30\n'
        '---\n',
        nov1));
    expect(card.meta['date'], '2026-11-03');
    expect(card.meta['start'], '07:30');
    expect(card.isDaily, isTrue);
  });

  test('@daily is a reserved tag, not a mention', () {
    expect(TodoTags.hasDaily('Dar ração @daily'), isTrue);
    expect(TodoTags.stripDaily('Dar ração @daily'), 'Dar ração');
    expect(TodoTags.handles('Dar ração @daily @Ana'), ['Ana']);
  });

  group('rollover', () {
    final doneYesterday = _todo(daily,
        done: true, completedAt: DateTime(2026, 11, 1, 10).toUtc());

    test('waits for the start time on the next day', () {
      final early = DateTime(2026, 11, 2, 8, 59);
      expect(TodoDaily.rollover(doneYesterday, early), isNull);
      // Ticked yesterday: out of the list until then.
      expect(TodoDaily.isListed(doneYesterday, early), isFalse);
      expect(TodoDaily.nextRollover([doneYesterday], early),
          DateTime(2026, 11, 2, 9));
    });

    test('unticks, pins and moves the date once it is due', () {
      final fields =
          TodoDaily.rollover(doneYesterday, DateTime(2026, 11, 2, 9, 0))!;
      expect(fields['is_completed'], isFalse);
      expect(fields['completed_at'], isNull);
      expect(fields['today_on'], '2026-11-02');
      expect(TodoCard.parse(fields['title']).meta['date'], '2026-11-02');
    });

    test('ticked today stays done until tomorrow', () {
      final today = _todo(daily,
          done: true, completedAt: DateTime(2026, 11, 1, 12).toUtc());
      expect(TodoDaily.rollover(today, nov1), isNull);
      expect(TodoDaily.isListed(today, nov1), isTrue);
    });

    test('a postponed date does not roll over', () {
      final later = TodoDaily.toDaily(
          '---\ntype: event\ntitle: X\ndate: 2026-11-05\n---\n', nov1);
      expect(TodoDaily.rollover(_todo(later), DateTime(2026, 11, 2, 12)),
          isNull);
    });

    test('ignores normal events', () {
      final event = _todo('---\ntype: event\ntitle: X\ndate: 2026-10-01\n---\n');
      expect(TodoDaily.rollover(event, nov1), isNull);
    });
  });

  group('monthly', () {
    String monthly(String date, int day, {String start = '09:00'}) =>
        '---\ntype: event\ntitle: Aluguel\ndate: $date\nstart: $start\n'
        'repeat: monthly\nmonthday: $day\n---\n';
    DateTime? rolledTo(String title, DateTime now) {
      final fields = TodoDaily.rollover(_todo(title, done: true), now);
      return fields == null
          ? null
          : TodoCard.parse(fields['title'] as String).date;
    }

    test('occurrence falls on the 1st when the month is too short', () {
      expect(TodoDaily.monthlyOccurrence(2026, 11, 31), DateTime(2026, 12, 1));
      expect(TodoDaily.monthlyOccurrence(2026, 2, 29), DateTime(2026, 3, 1));
      expect(TodoDaily.monthlyOccurrence(2028, 2, 29), DateTime(2028, 2, 29));
      expect(TodoDaily.monthlyOccurrence(2026, 12, 15), DateTime(2026, 12, 15));
    });

    test('stays done until its day, then comes back at its time', () {
      final title = monthly('2026-10-05', 5);
      expect(rolledTo(title, DateTime(2026, 11, 4, 23)), isNull);
      expect(rolledTo(title, DateTime(2026, 11, 5, 8, 59)), isNull);
      expect(rolledTo(title, DateTime(2026, 11, 5, 9)), DateTime(2026, 11, 5));
    });

    test('rollover keeps the month day and pins it', () {
      final fields = TodoDaily.rollover(
        _todo(monthly('2026-10-05', 5), done: true),
        DateTime(2026, 11, 5, 10),
      )!;
      final card = TodoCard.parse(fields['title'] as String);
      expect(card.isMonthly, isTrue);
      expect(card.meta['monthday'], '5');
      expect(fields['is_completed'], isFalse);
      expect(fields['today_on'], '2026-11-05');
    });

    test('a 31st rolls into the 1st of a 30-day month and back', () {
      final oct = monthly('2026-10-31', 31);
      expect(rolledTo(oct, DateTime(2026, 11, 30, 12)), isNull);
      expect(rolledTo(oct, DateTime(2026, 12, 1, 9)), DateTime(2026, 12, 1));
      // Then the 31st of December, not the 1st of January.
      final dec1 = monthly('2026-12-01', 31);
      expect(rolledTo(dec1, DateTime(2026, 12, 30, 12)), isNull);
      expect(rolledTo(dec1, DateTime(2026, 12, 31, 9)), DateTime(2026, 12, 31));
    });

    test('a missed occurrence comes back as soon as it is seen', () {
      final title = monthly('2026-09-05', 5);
      // Before 09:00 on the 7th: the 5th was already due.
      expect(rolledTo(title, DateTime(2026, 11, 7, 6)), DateTime(2026, 11, 5));
    });

    test('monthDay falls back to the date', () {
      final card = TodoCard.parse(
        '---\ntype: event\ndate: 2026-11-20\nrepeat: monthly\n---\n',
      );
      expect(card.monthDay, 20);
      expect(card.isRepeating, isTrue);
    });

    test('nextRollover only counts today\'s pending time', () {
      final title = monthly('2026-10-05', 5, start: '18:00');
      expect(
        TodoDaily.nextRollover([_todo(title)], DateTime(2026, 11, 5, 10)),
        DateTime(2026, 11, 5, 18),
      );
      expect(
        TodoDaily.nextRollover([_todo(title)], DateTime(2026, 11, 4, 10)),
        isNull,
      );
    });
  });
}
