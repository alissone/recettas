import 'package:flutter/material.dart';

import 'category_base.dart';

/// The kinds of card a todo can be displayed as.
enum TodoKind {
  todo('todo', 'Tarefa', Icons.check_box_outlined),
  move('move', 'Levar', Icons.local_shipping_outlined),
  event('event', 'Evento', Icons.event_outlined);

  final String key;
  final String label;
  final IconData icon;

  const TodoKind(this.key, this.label, this.icon);

  static TodoKind? fromKey(String? key) {
    for (final k in values) {
      if (k.key == key) return k;
    }
    return null;
  }
}

/// A todo's `title` split into its card type, metadata and markdown body.
///
/// Nothing new is stored in the database: non-plain cards keep their
/// metadata as a YAML-style front matter block at the top of the title,
/// e.g.
///
/// ```
/// ---
/// type: move
/// from: Casa
/// to: Trabalho
/// ---
/// - [ ] Carregador
/// ```
///
/// A plain todo has no front matter at all, so older rows (and text that
/// only happens to start with `---`) keep rendering exactly as before.
/// Converting between kinds only rewrites the front matter; [body] is
/// carried over untouched.
class TodoCard {
  final TodoKind kind;
  final Map<String, String> meta;
  final String body;

  const TodoCard({
    required this.kind,
    this.meta = const {},
    required this.body,
  });

  factory TodoCard.parse(String text) {
    final plain = TodoCard(kind: TodoKind.todo, body: text);
    final normalized = text.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('---\n')) return plain;
    final lines = normalized.split('\n');
    final close = lines.indexOf('---', 1);
    if (close < 0) return plain;

    final meta = <String, String>{};
    for (final line in lines.sublist(1, close)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      meta[line.substring(0, colon).trim()] =
          _unquote(line.substring(colon + 1).trim());
    }
    final kind = TodoKind.fromKey(meta.remove('type'));
    // Unknown front matter is left in the text rather than swallowed.
    if (kind == null || kind == TodoKind.todo) return plain;
    return TodoCard(
      kind: kind,
      meta: meta,
      body: lines.sublist(close + 1).join('\n'),
    );
  }

  static String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  /// The text stored in the todo's `title` column.
  String serialize() {
    if (kind == TodoKind.todo) return body;
    final buffer = StringBuffer('---\ntype: ${kind.key}\n');
    meta.forEach((key, value) {
      final v = value.replaceAll('\n', ' ').trim();
      if (v.isNotEmpty) buffer.write('$key: $v\n');
    });
    buffer.write('---\n');
    buffer.write(body);
    return buffer.toString();
  }

  // --- Move ("levar de/para") ---

  String get from => meta['from'] ?? '';
  String get to => meta['to'] ?? '';

  // --- Event ---

  String get eventTitle => meta['title'] ?? '';
  DateTime? get date => DateTime.tryParse(meta['date'] ?? '');
  TimeOfDay? get start => parseTime(meta['start']);
  TimeOfDay? get end => parseTime(meta['end']);

  static TimeOfDay? parseTime(String? value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// One-line label for places where the whole card doesn't fit (the
  /// categorize overlay, for instance).
  String get summary {
    final firstLine = body.trim().split('\n').first;
    switch (kind) {
      case TodoKind.todo:
        return firstLine;
      case TodoKind.move:
        return '${from.isEmpty ? '?' : from} → ${to.isEmpty ? '?' : to}';
      case TodoKind.event:
        return eventTitle.isNotEmpty ? eventTitle : firstLine;
    }
  }

  /// Stable color for a place name, drawn from the category palette so
  /// "Casa" looks the same on every card without having to be set up.
  static Color placeColor(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return const Color(0xFFBCAAA4);
    var hash = 0;
    for (final unit in normalized.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    const colors = CategoryBase.presetColors;
    return Color(colors[hash % colors.length]);
  }
}
