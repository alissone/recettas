import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../screens/files_screen.dart';
import '../utils/file_types.dart';
import 'cloud_file_repository.dart';
import 'supabase_service.dart';

/// Lets the OS share sheet ("Compartilhar" -> Recettas) drop files into
/// the Arquivos drive: one or many files of any type, from any app
/// (including a PDF viewer). Mobile only - the web build never imports it.
///
/// The app is launched (or brought forward) by the share; each shared
/// file is uploaded right away and a snackbar reports the result.
class ShareIntake {
  ShareIntake._();

  static final ShareIntake instance = ShareIntake._();

  /// Wired into the MaterialApp so a share can show feedback and open
  /// the file list from outside any widget.
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  /// Shares are handled one batch at a time, in arrival order.
  Future<void> _queue = Future.value();

  Future<void> init() async {
    // iOS has no share extension; it receives files through
    // IncomingFilesService (document handler) instead.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final sharing = ReceiveSharingIntent.instance;
    // App was launched by the share...
    final initial = await sharing.getInitialMedia();
    if (initial.isNotEmpty) _enqueue(initial);
    // ...or was already running and got another one.
    _subscription ??= sharing.getMediaStream().listen(
          _enqueue,
          onError: (Object e) => debugPrint('Share intake error: $e'),
        );
  }

  void _enqueue(List<SharedMediaFile> media) {
    if (media.isEmpty) return;
    // Consumed: don't deliver the same share again on the next launch.
    ReceiveSharingIntent.instance.reset();
    _queue = _queue.then((_) => _upload(media)).catchError((Object e) {
      debugPrint('Share upload failed: $e');
    });
  }

  Future<void> _upload(List<SharedMediaFile> media) async {
    if (SupabaseService.currentUser == null) {
      _toast('Entre na sua conta para enviar arquivos compartilhados');
      return;
    }
    final repo = CloudFileRepository.instance;
    var sent = 0;
    final failures = <String>[];

    for (var i = 0; i < media.length; i++) {
      final item = media[i];
      _toast(media.length == 1
          ? 'Enviando arquivo...'
          : 'Enviando arquivo ${i + 1} de ${media.length}...');
      final name = _nameFor(item);
      try {
        final Uint8List bytes = _isText(item)
            ? Uint8List.fromList(utf8.encode(item.path))
            : await File(item.path).readAsBytes();
        await repo.upload(
          name: name,
          bytes: bytes,
          mimeType: mimeTypeForName(name) ?? item.mimeType,
        );
        sent++;
      } catch (e) {
        failures.add('$name ($e)');
      } finally {
        _deleteTemp(item);
      }
    }

    if (failures.isEmpty) {
      _toast(sent == 1 ? 'Arquivo enviado' : '$sent arquivos enviados',
          openFiles: true);
    } else {
      _toast('$sent enviado(s); falhou: ${failures.join('; ')}',
          openFiles: sent > 0);
    }
  }

  /// Text and links arrive as the text itself; they become a .txt file.
  static bool _isText(SharedMediaFile item) =>
      item.type == SharedMediaType.text || item.type == SharedMediaType.url;

  String _nameFor(SharedMediaFile item) {
    if (_isText(item)) {
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      return 'Texto ${now.year}-${two(now.month)}-${two(now.day)} '
          '${two(now.hour)}.${two(now.minute)}.${two(now.second)}.txt';
    }
    return p.basename(item.path);
  }

  /// Shared files are copied to a cache folder; clear ours once uploaded.
  void _deleteTemp(SharedMediaFile item) {
    if (_isText(item)) return;
    unawaited(File(item.path).delete().then((_) {}, onError: (Object _) {}));
  }

  void _toast(String message, {bool openFiles = false}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: openFiles
            ? SnackBarAction(
                label: 'Ver',
                onPressed: () => navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const FilesScreen()),
                ),
              )
            : null,
      ));
  }
}
