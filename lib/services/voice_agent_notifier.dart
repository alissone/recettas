import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models/voice_note.dart';
import '../widgets/agent_confirm_dialog.dart';
import 'share_intake.dart';
import 'todo_repository.dart';
import 'voice_note_repository.dart';

/// Tells the user what the local assistant did with a voice note, from
/// anywhere in the app: a snackbar listing what it did (with "Desfazer"),
/// and a dialog for the actions it wasn't sure of.
///
/// The worker sets agent_notified = false when it finishes; this listens
/// for that over Realtime (and checks on start/resume, in case the app
/// was closed), shows it once, and sets agent_notified = true.
class VoiceAgentNotifier {
  VoiceAgentNotifier._();

  static final VoiceAgentNotifier instance = VoiceAgentNotifier._();

  SupabaseClient get _client => Supabase.instance.client;
  final _repo = VoiceNoteRepository.instance;

  RealtimeChannel? _channel;
  AppLifecycleListener? _lifecycle;

  /// Notes being shown, so a realtime event and a check don't both fire.
  final Set<String> _handling = {};

  /// One notice at a time, in order.
  Future<void> _queue = Future.value();

  Future<void> init() async {
    _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _stop();
      } else if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        _start();
      }
    });
    _lifecycle ??= AppLifecycleListener(onResume: _checkPending);
    if (_client.auth.currentUser != null) _start();
  }

  void _start() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    _channel?.unsubscribe();
    _channel = _client
        .channel('voice-agent-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'voice_notes',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (payload) {
            try {
              final note = VoiceNote.fromJson(payload.newRecord);
              if (note.agentNeedsNotice) _enqueue(note);
            } catch (e) {
              debugPrint('Voice agent payload: $e');
            }
          },
        )
        .subscribe();
    _checkPending();
  }

  void _stop() {
    _channel?.unsubscribe();
    _channel = null;
    _handling.clear();
  }

  Future<void> _checkPending() async {
    if (_client.auth.currentUser == null) return;
    try {
      for (final note in await _repo.unnotifiedAgentNotes()) {
        _enqueue(note);
      }
    } catch (e) {
      // Offline, or a server without migration 046: nothing to show.
      debugPrint('Voice agent check failed: $e');
    }
  }

  void _enqueue(VoiceNote note) {
    if (!_handling.add(note.id)) return;
    _queue = _queue
        .then((_) => _show(note))
        .catchError((Object e) => debugPrint('Voice agent notice: $e'))
        .whenComplete(() => _handling.remove(note.id));
  }

  Future<void> _show(VoiceNote note) async {
    // Marked first: a crash below must not replay the notice forever.
    await _repo.markAgentNotified(note.id);

    final done = note.agentActions.where((a) => a.isDone).toList();
    final failed = note.agentActions.where((a) => a.status == 'error').toList();
    final pending = note.agentActions.where((a) => a.isPending).toList();

    if (done.any((a) => a.tool == 'add_todos' || a.tool == 'create_event')) {
      unawaited(TodoRepository.instance.sync());
    }
    if (done.isNotEmpty || failed.isNotEmpty) _snack(note, done, failed);
    if (pending.isNotEmpty) await _confirm(note, pending);
  }

  void _snack(VoiceNote note, List<VoiceAgentAction> done,
      List<VoiceAgentAction> failed) {
    final messenger = ShareIntake.instance.messengerKey.currentState;
    if (messenger == null) return;
    final parts = [
      for (final a in done) a.summary,
      for (final a in failed) 'Falhou: ${a.summary}',
    ];
    messenger.showSnackBar(SnackBar(
      content: Text('Assistente • ${parts.join(' • ')}'),
      backgroundColor: failed.isEmpty ? Colors.green.shade700 : AppTheme.darkBrown,
      duration: const Duration(seconds: 8),
      action: done.isEmpty
          ? null
          : SnackBarAction(
              label: 'Desfazer',
              textColor: Colors.white,
              onPressed: () => _repo
                  .applyAgentActions(note, {for (final a in done) a.id: 'undo'})
                  .catchError((Object e) => debugPrint('Undo failed: $e')),
            ),
    ));
  }

  Future<void> _confirm(VoiceNote note, List<VoiceAgentAction> pending) async {
    final context = ShareIntake.instance.navigatorKey.currentContext;
    if (context == null) return;
    final result = await AgentConfirmDialog.show(context, pending);
    // Dismissed: they stay pending on the note (Notas de voz).
    if (result == null) return;
    await _repo.applyAgentActions(note, result);
    final n = result.values.where((s) => s == 'confirmed').length;
    if (n > 0) {
      ShareIntake.instance.messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(n == 1
            ? 'Confirmado - o PC vai lançar agora'
            : '$n confirmados - o PC vai lançar agora'),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }
}
