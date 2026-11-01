import 'contact.dart';
import 'todo_card.dart';

/// "@" tags in a todo's text, Slack-style.
///
/// `@nickname` tags a contact from "Pessoas"; the tag stays in the text
/// and is what decides who the todo is shared with. `@today` (or `@hoje`)
/// pins the todo to the top of the list for the rest of the day: it is
/// stripped from the text on save and stored as `today_on` instead, so an
/// expired pin doesn't leave a stale "@today" behind. `@daily` (or
/// `@diario`) turns the todo into an event that repeats every day; it is
/// stripped too, and kept as `repeat: daily` on the card (see TodoDaily).
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

  static const dailyWords = {'daily', 'diario', 'diário'};

  static const dailyToken = '@daily';

  static bool isTodayWord(String handle) =>
      todayWords.contains(handle.toLowerCase());

  static bool isDailyWord(String handle) =>
      dailyWords.contains(handle.toLowerCase());

  /// Words that can't be a contact's nickname.
  static bool isReservedWord(String handle) =>
      isTodayWord(handle) || isDailyWord(handle);

  /// One of [words] as a whole tag, plus the space before it.
  static RegExp _tag(Set<String> words) => RegExp(
        r'[ \t]?(?<![\p{L}\p{N}_@.])@(' +
            words.join('|') +
            r')(?![\p{L}\p{N}_.\-]*[\p{L}\p{N}_])',
        caseSensitive: false,
        unicode: true,
      );

  static final _todayTag = _tag(todayWords);
  static final _dailyTag = _tag(dailyWords);

  static bool hasToday(String text) => _todayTag.hasMatch(text);

  static String stripToday(String text) =>
      text.replaceAll(_todayTag, '').trim();

  static bool hasDaily(String text) => _dailyTag.hasMatch(text);

  static String stripDaily(String text) =>
      text.replaceAll(_dailyTag, '').trim();

  /// The handles tagged in [text], without `@today`/`@daily`, in order,
  /// once each.
  static List<String> handles(String text) {
    final seen = <String>{};
    final result = <String>[];
    for (final m in mention.allMatches(text)) {
      final handle = m.group(1)!;
      if (isReservedWord(handle)) continue;
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
