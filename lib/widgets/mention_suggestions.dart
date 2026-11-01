import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/contact.dart';
import '../models/todo_tags.dart';

/// Slack-style "@" autocomplete for a todo text field: while the word at
/// the cursor starts with "@", shows a row of matching nicknames (plus
/// `@today`); tapping one completes the word. Renders nothing otherwise.
class MentionSuggestions extends StatefulWidget {
  final TextEditingController controller;
  final List<Contact> contacts;

  const MentionSuggestions({
    super.key,
    required this.controller,
    required this.contacts,
  });

  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  /// An "@word" being typed right before the cursor (see TodoTags.mention).
  static final _partial =
      RegExp(r'(?<![\p{L}\p{N}_@.])@([\p{L}\p{N}_.\-]*)$', unicode: true);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(MentionSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _complete(int start, String handle) {
    final value = widget.controller.value;
    final end = value.selection.baseOffset;
    final insert = '@$handle ';
    widget.controller.value = TextEditingValue(
      text: value.text.replaceRange(start, end, insert),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final sel = value.selection;
    if (!sel.isValid || !sel.isCollapsed) return const SizedBox.shrink();
    final match =
        _partial.firstMatch(value.text.substring(0, sel.baseOffset));
    if (match == null) return const SizedBox.shrink();
    final query = match.group(1)!.toLowerCase();

    final chips = <Widget>[
      if (TodoTags.todayWords.any((w) => w.startsWith(query)))
        _chip(
          icon: Icons.today,
          label: TodoTags.todayToken,
          onTap: () =>
              _complete(match.start, TodoTags.todayToken.substring(1)),
        ),
      for (final c in widget.contacts)
        if (c.nickname.toLowerCase().startsWith(query))
          _chip(
            icon: c.hasAccount ? Icons.person : Icons.person_outline,
            label: '@${c.nickname}',
            onTap: () => _complete(match.start, c.nickname),
          ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    // Counts as part of the text field, so tapping a chip doesn't
    // unfocus it (desktop) or trigger "tap outside to save".
    return TextFieldTapRegion(
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppTheme.primaryOrange),
      label: Text(label),
      labelStyle: const TextStyle(
        color: AppTheme.darkBrown,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppTheme.white,
      side: BorderSide(color: AppTheme.borderOrange),
      onPressed: onTap,
    );
  }
}
