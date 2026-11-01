import 'package:flutter/material.dart' show TimeOfDay;

import 'todo.dart';
import 'todo_card.dart';
import 'todo_tags.dart';

/// "@daily" todos: events with `repeat: daily` that come back every day
/// until they're deleted.
///
/// The card's `date` is the current occurrence. Once a later day reaches
/// the event's start time (09:00 when none is set), the todo rolls over:
/// the date moves to today, it's unticked even if it was done, and it's
/// pinned like "@today" so it sits at the top. Until that time it keeps
/// yesterday's state — if it was ticked, it stays out of the list, like
/// any todo completed on an earlier day.
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

  /// Its occurrence is from an earlier day (or has no date), so it rolls
  /// over at today's start time. False for today's or a postponed date.
  static bool _isBehind(TodoCard card, DateTime now) {
    final date = card.date;
    return date == null || _midnight(date).isBefore(_midnight(now));
  }

  /// The fields that roll [todo] over to today, or null when it isn't a
  /// daily todo or it isn't time yet.
  static Map<String, dynamic>? rollover(Todo todo, [DateTime? now]) {
    now ??= DateTime.now();
    final card = TodoCard.parse(todo.title);
    if (!card.isDaily || !_isBehind(card, now)) return null;
    if (now.isBefore(dueOn(card, now))) return null;
    return {
      'title': TodoCard(
        kind: card.kind,
        meta: {...card.meta, 'date': TodoCard.formatDate(now)},
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
      if (!card.isDaily || !_isBehind(card, now)) continue;
      final due = dueOn(card, now);
      if (due.isAfter(now) && (next == null || due.isBefore(next))) {
        next = due;
      }
    }
    return next;
  }

  /// Whether [todo] belongs in the list. Ticked todos only stay for the
  /// day they were ticked on; a daily one ticked yesterday is waiting for
  /// today's start time (when [rollover] brings it back).
  static bool isListed(Todo todo, [DateTime? now]) {
    if (!todo.isCompleted) return true;
    final completedAt = todo.completedAt;
    return completedAt != null &&
        !completedAt.toLocal().isBefore(_midnight(now ?? DateTime.now()));
  }
}
