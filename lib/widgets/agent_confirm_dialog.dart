import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/voice_note.dart';

/// Asks the user about the actions the local assistant wasn't sure of.
/// All are checked by default; pops {action id: 'confirmed' | 'discarded'}
/// or null when dismissed (the actions stay pending on the note).
class AgentConfirmDialog extends StatefulWidget {
  final List<VoiceAgentAction> actions;

  const AgentConfirmDialog({super.key, required this.actions});

  static Future<Map<String, String>?> show(
      BuildContext context, List<VoiceAgentAction> actions) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AgentConfirmDialog(actions: actions),
    );
  }

  @override
  State<AgentConfirmDialog> createState() => _AgentConfirmDialogState();
}

class _AgentConfirmDialogState extends State<AgentConfirmDialog> {
  late final List<bool> _checked = List.filled(widget.actions.length, true);

  Map<String, String> _result({required bool confirm}) => {
        for (var i = 0; i < widget.actions.length; i++)
          widget.actions[i].id:
              confirm && _checked[i] ? 'confirmed' : 'discarded',
      };

  @override
  Widget build(BuildContext context) {
    final count = _checked.where((c) => c).length;
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: const Text('Confirmar o que entendi?',
          style: AppTheme.sectionTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.actions.length,
          itemBuilder: (_, i) {
            final a = widget.actions[i];
            return CheckboxListTile(
              value: _checked[i],
              activeColor: AppTheme.primaryOrange,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(a.summary, style: AppTheme.bodyText),
              subtitle: a.reason == null
                  ? null
                  : Text(a.reason!, style: AppTheme.caption),
              onChanged: (v) => setState(() => _checked[i] = v ?? false),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _result(confirm: false)),
          child: Text('Descartar',
              style: TextStyle(color: Colors.red.shade300)),
        ),
        ElevatedButton(
          onPressed: count == 0
              ? null
              : () => Navigator.pop(context, _result(confirm: true)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
          ),
          child: Text('Confirmar ($count)'),
        ),
      ],
    );
  }
}
