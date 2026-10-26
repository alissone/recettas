import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../models/cloud_file.dart';
import '../utils/file_types.dart';
import 'cloud_file_repository.dart';
import 'supabase_service.dart';

/// Files shared into Recettas from other apps, uploaded into Arquivos.
///
/// iOS has no share extension here (App Groups need a paid developer
/// account, see ios/Runner/IncomingFiles.swift) - Recettas is registered
/// as a document handler instead, so sharing a file to it copies the file
/// over and launches the app.
///
/// The native side queues whatever it receives and this pulls, on startup
/// and on every resume, rather than being pushed to: a file shared while
/// the engine was still booting is then picked up on the next pass
/// instead of being dropped. A share that arrives while signed out is
/// held until the session comes back.
class IncomingFilesService with WidgetsBindingObserver {
  IncomingFilesService._();

  static final IncomingFilesService instance = IncomingFilesService._();

  static const _channel = MethodChannel('recettas/incoming_files');

  /// What last happened to a shared file. Read by HomeShell, which
  /// raises the banner, and by the Arquivos screen when it's open, which
  /// inserts the row. Both listeners dedupe on [IncomingFileEvent.seq]
  /// rather than clearing this - whoever cleared it first would hide the
  /// event from the other.
  final ValueNotifier<IncomingFileEvent?> lastEvent = ValueNotifier(null);

  int _seq = 0;

  /// Shares taken off the native queue but not yet uploaded - either the
  /// user was signed out, or an upload is already running.
  final List<_SharedFile> _queue = [];

  StreamSubscription<AuthState>? _authSubscription;
  bool _draining = false;

  /// Only iOS routes shares here today; everywhere else the channel has
  /// no handler and every call would throw.
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> init() async {
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    // Signing in is what unblocks a share that arrived while signed out.
    _authSubscription ??= SupabaseService.authDataChanges.listen(
      (_) => unawaited(_drain()),
      onError: (_) {},
    );
    await collect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sharing into Recettas foregrounds it, so this is where a share
    // into the already-running app shows up.
    if (state == AppLifecycleState.resumed) unawaited(collect());
  }

  /// Takes whatever the native side is holding and uploads it.
  Future<void> collect() async {
    if (!_supported) return;
    try {
      final pending =
          await _channel.invokeListMethod<Map<Object?, Object?>>('takePending');
      if (pending == null || pending.isEmpty) return;
      for (final file in pending) {
        final name = file['name'] as String?;
        final bytes = file['bytes'] as Uint8List?;
        if (name == null || bytes == null) continue;
        _queue.add(_SharedFile(name, bytes));
        debugPrint('Shared file received: "$name" (${bytes.length} bytes)');
      }
    } on PlatformException catch (e) {
      debugPrint('Could not read shared files: $e');
      return;
    } on MissingPluginException {
      // Running against a build without the native half.
      return;
    }
    await _drain();
  }

  Future<void> _drain() async {
    if (_draining || _queue.isEmpty) return;
    // Nothing to upload to yet; the auth listener calls back on sign-in.
    if (SupabaseService.currentUser == null) return;

    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        if (SupabaseService.currentUser == null) return;
        final file = _queue.first;
        try {
          final saved = await CloudFileRepository.instance.upload(
            name: file.name,
            bytes: file.bytes,
            mimeType: mimeTypeForName(file.name),
          );
          _queue.removeAt(0);
          lastEvent.value = IncomingFileEvent(seq: ++_seq, file: saved);
        } catch (e) {
          // The bytes are only held in memory, so a failed share is
          // dropped rather than retried forever - the user still has the
          // original and can share it again.
          _queue.removeAt(0);
          debugPrint('Shared file "${file.name}" failed to upload: $e');
          lastEvent.value =
              IncomingFileEvent(seq: ++_seq, failedName: file.name);
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// The seq a listener should start from so opening a screen doesn't
  /// replay the share it already loaded from the server.
  int get currentSeq => lastEvent.value?.seq ?? 0;
}

/// One outcome for one shared file. [seq] only ever rises, so a listener
/// can tell a fresh event from the one it has already handled - which a
/// nullable value alone can't do when two files share a name.
class IncomingFileEvent {
  const IncomingFileEvent({required this.seq, this.file, this.failedName});

  final int seq;

  /// Set when the share made it into Arquivos.
  final CloudFile? file;

  /// Set instead when the upload failed.
  final String? failedName;
}

class _SharedFile {
  _SharedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}
