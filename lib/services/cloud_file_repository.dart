import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/cloud_file.dart';

/// "Arquivos": a small cross-device drive. Bytes go to the private
/// "cloud-files" bucket (keyed `<user_id>/<file_id>`), the listing to the
/// cloud_files table, and every upload/download is logged with the
/// device's name in cloud_file_events.
///
/// Talks to Supabase directly and avoids dart:io so the web build can
/// use it too.
class CloudFileRepository {
  CloudFileRepository._();

  static final CloudFileRepository instance = CloudFileRepository._();

  static const _uuid = Uuid();
  static const _bucket = 'cloud-files';
  static const _table = 'cloud_files';
  static const _eventsTable = 'cloud_file_events';
  static const _chatBucket = 'chat-files';

  /// Matches the bucket's file_size_limit (migration 037).
  static const maxBytes = 25 * 1024 * 1024;

  SupabaseClient get _client => Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  String? _deviceName;

  /// Readable name of this device for the upload/download history.
  Future<String> deviceName() async {
    return _deviceName ??= await _lookupDeviceName();
  }

  Future<String> _lookupDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final browser = (await info.webBrowserInfo).browserName.name;
        return '${browser[0].toUpperCase()}${browser.substring(1)} (Web)';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await info.androidInfo;
          return '${a.manufacturer} ${a.model} (Android)';
        case TargetPlatform.iOS:
          // iOS 16+ reports a generic "iPhone" as the device name.
          return '${(await info.iosInfo).name} (iOS)';
        case TargetPlatform.windows:
          return '${(await info.windowsInfo).computerName} (Windows)';
        case TargetPlatform.macOS:
          return '${(await info.macOsInfo).computerName} (macOS)';
        case TargetPlatform.linux:
          return '${(await info.linuxInfo).prettyName} (Linux)';
        case TargetPlatform.fuchsia:
          break;
      }
    } catch (e) {
      debugPrint('Device name lookup failed: $e');
    }
    return 'Dispositivo desconhecido';
  }

  Future<List<CloudFile>> getFiles() async {
    final data = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return data.map<CloudFile>(CloudFile.fromJson).toList();
  }

  Future<CloudFile> upload({
    required String name,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (bytes.length > maxBytes) {
      throw 'Arquivo maior que ${CloudFile.formatSize(maxBytes)}';
    }
    final id = _uuid.v4();
    final path = '$_userId/$id';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? 'application/octet-stream',
            upsert: true,
          ),
        );
    try {
      final row = await _client.from(_table).insert({
        'id': id,
        'user_id': _userId,
        'name': name,
        'size_bytes': bytes.length,
        'mime_type': mimeType,
        'storage_path': path,
      }).select().single();
      await _logEvent(id, CloudFileEventKind.upload);
      return CloudFile.fromJson(row);
    } catch (_) {
      // Don't leave an orphan object that no row points at.
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<Uint8List> download(CloudFile file) =>
      _client.storage.from(_bucket).download(file.storagePath);

  /// Records a download from this device. Called once the bytes were
  /// actually saved, so a cancelled save dialog doesn't count. Never
  /// throws: the history is secondary to the download itself.
  Future<void> logDownload(CloudFile file) async {
    try {
      await _logEvent(file.id, CloudFileEventKind.download);
    } catch (e) {
      debugPrint('Could not log download: $e');
    }
  }

  Future<void> rename(CloudFile file, String name) async {
    await _client.from(_table).update({
      'name': name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', file.id);
  }

  Future<void> delete(CloudFile file) async {
    await _client.storage.from(_bucket).remove([file.storagePath]);
    await _client.from(_table).delete().eq('id', file.id);
  }

  Future<List<CloudFileEvent>> getEvents(CloudFile file) async {
    final data = await _client
        .from(_eventsTable)
        .select()
        .eq('file_id', file.id)
        .order('created_at');
    return data.map<CloudFileEvent>(CloudFileEvent.fromJson).toList();
  }

  // --- Chat attachments (migration 038) ---

  /// Uploads [bytes] to the chat bucket and sends a message pointing at
  /// it. The message id is generated here so the object path
  /// (`<room_id>/<message_id>`) and the row share it.
  Future<void> sendChatAttachment({
    required String roomId,
    required String name,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (bytes.length > maxBytes) {
      throw 'Arquivo maior que ${CloudFile.formatSize(maxBytes)}';
    }
    final me = _client.auth.currentUser!;
    final id = _uuid.v4();
    final path = '$roomId/$id';
    await _client.storage.from(_chatBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? 'application/octet-stream',
            upsert: true,
          ),
        );
    try {
      await _client.from('chat_messages').insert({
        'id': id,
        'room_id': roomId,
        'sender_id': me.id,
        'sender_email': me.email!.toLowerCase(),
        'content': '\u{1F4CE} $name',
        'file_name': name,
        'file_size': bytes.length,
        'file_mime': mimeType,
        'file_path': path,
      });
    } catch (_) {
      try {
        await _client.storage.from(_chatBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<Uint8List> downloadChatAttachment(String path) =>
      _client.storage.from(_chatBucket).download(path);

  Future<void> _logEvent(String fileId, CloudFileEventKind kind) async {
    await _client.from(_eventsTable).insert({
      'file_id': fileId,
      'user_id': _userId,
      'kind': kind.name,
      'device_name': await deviceName(),
    });
  }
}
