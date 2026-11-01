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
}
