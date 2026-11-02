import 'package:flutter/material.dart' show TimeOfDay;

import 'todo.dart';
import 'todo_card.dart';
import 'todo_tags.dart';

/// Repeating todos: events with `repeat: daily` ("@daily") that come back
/// every day, or `repeat: monthly` that come back every month on day
/// `monthday`, until they're deleted.
///
/// The card's `date` is the current occurrence. Once a newer occurrence's
/// day reaches the event's start time (09:00 when none is set), the todo
/// rolls over: the date moves to that occurrence, it's unticked even if it
/// was done, and it's pinned like "@today" so it sits at the top. Until
/// then it keeps its previous state — if it was ticked, it stays out of
/// the list, like any todo completed on an earlier day. A monthly day the
/// month doesn't have (the 31st in November) falls on the 1st of the next
/// month; an occurrence missed entirely (app not opened that day) rolls
/// over as soon as it's seen.
///
/// Nothing runs on the server: whichever client sees the todo first after
/// the start time writes the rollover (the same fields every time, so two
/// clients doing it at once is harmless). web/print.html has a JavaScript
/// copy of these rules.
class TodoDaily {
  TodoDaily._();

  static const defaultStart = TimeOfDay(hour: 9, minute: 0);

  /// Turns [text] (already without the "@daily" tag) into a daily event:
  /// a plain todo's first line becomes the event title and the rest its
  /// notes. Date defaults to today and start to [defaultStart]; an
  /// existing event keeps the ones it has.
  static String toDaily(String text, [DateTime? now]) {
    now ??= DateTime.now();
    final card = TodoCard.parse(text);
    final meta = <String, String>{};
    var body = card.body;
    switch (card.kind) {
      case TodoKind.event:
        meta.addAll(card.meta);
      case TodoKind.todo:
        final lines = card.body.split('\n');
        meta['title'] = lines.first.trim();
        body = lines.skip(1).join('\n').trim();
      case TodoKind.move:
        meta['title'] = card.summary;
    }
    meta['date'] ??= TodoCard.formatDate(now);
    meta['start'] ??= TodoCard.formatTime(defaultStart);
    meta['repeat'] = 'daily';
    return TodoCard(kind: TodoKind.event, meta: meta, body: body).serialize();
  }

  /// When [card] is due on [now]'s day.
  static DateTime dueOn(TodoCard card, DateTime now) {
    final start = card.start ?? defaultStart;
    return DateTime(now.year, now.month, now.day, start.hour, start.minute);
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// A monthly event's occurrence in [year]/[month]: that [day], or the
  /// 1st of the following month when the month is too short for it.
  static DateTime monthlyOccurrence(int year, int month, int day) {
    final length = DateTime(year, month + 1, 0).day;
    return day <= length
        ? DateTime(year, month, day)
        : DateTime(year, month + 1, 1);
  }

  /// The latest occurrence of [card] on or before [now]'s day: today for
  /// a daily one.
  static DateTime latestOccurrence(TodoCard card, DateTime now) {
    final today = _midnight(now);
    if (!card.isMonthly) return today;
    final day = card.monthDay ?? 1;
    final occurrence = monthlyOccurrence(now.year, now.month, day);
    // Not yet this month: last month's (which may be today's 1st).
    return occurrence.isAfter(today)
        ? monthlyOccurrence(now.year, now.month - 1, day)
        : occurrence;
  }

  /// A newer occurrence than the card's date (or it has none), so it
  /// rolls over to [latestOccurrence]. False for the current or a
  /// postponed date.
  static bool _isBehind(TodoCard card, DateTime now) {
    final date = card.date;
    return date == null ||
        _midnight(date).isBefore(latestOccurrence(card, now));
  }

  /// Whether the newer occurrence's time has come: an earlier day's has,
  /// today's from its start time on.
  static bool _isDue(TodoCard card, DateTime now) =>
      latestOccurrence(card, now).isBefore(_midnight(now)) ||
      !now.isBefore(dueOn(card, now));

  /// The fields that roll [todo] over to its latest occurrence, or null
  /// when it isn't a repeating todo or it isn't time yet.
  static Map<String, dynamic>? rollover(Todo todo, [DateTime? now]) {
    now ??= DateTime.now();
    final card = TodoCard.parse(todo.title);
    if (!card.isRepeating || !_isBehind(card, now)) return null;
    if (!_isDue(card, now)) return null;
    return {
      'title': TodoCard(
        kind: card.kind,
        meta: {
          ...card.meta,
          'date': TodoCard.formatDate(latestOccurrence(card, now)),
          if (card.isMonthly) 'monthday': '${card.monthDay ?? 1}',
        },
        body: card.body,
      ).serialize(),
      'is_completed': false,
      'completed_at': null,
      'today_on': TodoTags.todayKey(now),
    };
  }

  /// When the next rollover among [todos] is due today, if any — so the
  /// list can refresh right then instead of on the next sync.
  static DateTime? nextRollover(Iterable<Todo> todos, [DateTime? now]) {
    now ??= DateTime.now();
    DateTime? next;
    for (final todo in todos) {
      final card = TodoCard.parse(todo.title);
      if (!card.isRepeating || !_isBehind(card, now)) continue;
      if (_isDue(card, now)) continue;
      final due = dueOn(card, now);
      if (due.isAfter(now) && (next == null || due.isBefore(next))) {
        next = due;
      }
    }
    return next;
  }

  /// Whether [todo] belongs in the list. Ticked todos only stay for the
  /// day they were ticked on; a repeating one ticked earlier is waiting
  /// for its next occurrence (when [rollover] brings it back).
  static bool isListed(Todo todo, [DateTime? now]) {
    if (!todo.isCompleted) return true;
    final completedAt = todo.completedAt;
    return completedAt != null &&
        !completedAt.toLocal().isBefore(_midnight(now ?? DateTime.now()));
  }
}
