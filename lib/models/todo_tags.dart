import 'contact.dart';
import 'todo_card.dart';

/// "@" tags in a todo's text, Slack-style.
///
/// `@nickname` tags a contact from "Pessoas"; the tag stays in the text
/// and is what decides who the todo is shared with. `@today` (or `@hoje`)
/// pins the todo to the top of the list for the rest of the day: it is
/// stripped from the text on save and stored as `today_on` instead, so an
/// expired pin doesn't leave a stale "@today" behind.
///
/// web/print.html has a JavaScript copy of [mention]; keep them in sync.
class TodoTags {
  TodoTags._();

  /// `@` not preceded by a word character (so e-mails don't match), then
  /// a handle that doesn't end in `.` or `-` ("@Ana." tags "Ana").
  static final mention = RegExp(
    r'(?<![\p{L}\p{N}_@.])@([\p{L}\p{N}_.\-]*[\p{L}\p{N}_])',
    unicode: true,
  );

  /// What a nickname may look like; the same characters [mention] reads.
  static final nicknamePattern =
      RegExp(r'^[\p{L}\p{N}_.\-]*[\p{L}\p{N}_]$', unicode: true);

  static const todayWords = {'today', 'hoje'};

  /// Token written back when a pinned todo is opened in the editor, so
  /// the pin round-trips (deleting it unpins).
  static const todayToken = '@today';

  static bool isTodayWord(String handle) =>
      todayWords.contains(handle.toLowerCase());

  static final _todayTag = RegExp(
    r'[ \t]?(?<![\p{L}\p{N}_@.])@(today|hoje)(?![\p{L}\p{N}_.\-]*[\p{L}\p{N}_])',
    caseSensitive: false,
    unicode: true,
  );

  static bool hasToday(String text) => _todayTag.hasMatch(text);

  static String stripToday(String text) =>
      text.replaceAll(_todayTag, '').trim();

  /// The handles tagged in [text], without `@today`, in order, once each.
  static List<String> handles(String text) {
    final seen = <String>{};
    final result = <String>[];
    for (final m in mention.allMatches(text)) {
      final handle = m.group(1)!;
      if (isTodayWord(handle)) continue;
      if (seen.add(handle.toLowerCase())) result.add(handle);
    }
    return result;
  }

  /// Contacts tagged in [text] (nicknames match case-insensitively).
  static List<Contact> taggedContacts(String text, List<Contact> contacts) {
    final byNickname = {
      for (final c in contacts) c.nickname.toLowerCase(): c,
    };
    return [
      for (final h in handles(text))
        if (byNickname[h.toLowerCase()] case final c?) c,
    ];
  }

  /// Accounts the todo gets shared with: tagged contacts that have one.
  static List<String> assigneeIds(String text, List<Contact> contacts) => [
        for (final c in taggedContacts(text, contacts))
          if (c.contactUserId != null) c.contactUserId!,
      ];

  /// The local date [todayOn] is compared against.
  static String todayKey([DateTime? now]) =>
      TodoCard.formatDate(now ?? DateTime.now());

  /// [title] with [todayToken] appended to the first line of its body.
  static String withToday(String title) {
    final card = TodoCard.parse(title);
    final lines = card.body.split('\n');
    final first = lines.first.trimRight();
    lines[0] = first.isEmpty ? todayToken : '$first $todayToken';
    return TodoCard(kind: card.kind, meta: card.meta, body: lines.join('\n'))
        .serialize();
  }
}
