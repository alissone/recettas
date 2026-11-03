import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/clipboard_item.dart';

/// Shared clipboard between the user's devices (app and web). "Send"
/// pushes this device's clipboard into clipboard_items; every other
/// device sees it live through [watch] and copies it with one tap.
/// Images go to the private "clipboard" bucket. Only the latest
/// [keep] items survive.
///
/// No dart:io, so the web build can use it too.
class ClipboardRepository {
  ClipboardRepository._();

  static final ClipboardRepository instance = ClipboardRepository._();

  static const _uuid = Uuid();
  static const _table = 'clipboard_items';
  static const _bucket = 'clipboard';

  /// How many items the history keeps.
  static const keep = 5;

  /// Matches the bucket's file_size_limit (migration 043).
  static const maxImageBytes = 10 * 1024 * 1024;

  SupabaseClient get _client => Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  /// The latest [keep] items, newest first, updating live.
  Stream<List<ClipboardItem>> watch() => _client
      .from(_table)
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(keep)
      .map((rows) => rows.map(ClipboardItem.fromJson).toList());

  // --- This device's clipboard ---

  /// Text currently on this device's clipboard, or null when empty or
  /// the browser refused to let the page read it.
  Future<String?> readText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      return text == null || text.trim().isEmpty ? null : text;
    } catch (e) {
      debugPrint('Clipboard text read failed: $e');
      return null;
    }
  }

  /// Image currently on this device's clipboard (PNG/JPEG bytes), or
  /// null when there is none or reading is blocked.
  Future<Uint8List?> readImage() async {
    try {
      final bytes = await Pasteboard.image;
      return bytes == null || bytes.isEmpty ? null : bytes;
    } catch (e) {
      debugPrint('Clipboard image read failed: $e');
      return null;
    }
  }

  Future<void> writeText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  /// Puts an image on this device's clipboard. The platform decides
  /// what formats it takes; PNG is the safe one.
  Future<void> writeImage(Uint8List bytes) => Pasteboard.writeImage(bytes);

  // --- Shared history ---

  Future<void> sendText(String text) async {
    await _client.from(_table).insert({
      'id': _uuid.v4(),
      'user_id': _userId,
      'kind': 'text',
      'content': text,
    });
    await _prune();
  }

  Future<void> sendImage(Uint8List bytes) async {
    if (bytes.length > maxImageBytes) {
      throw 'Imagem maior que 10 MB';
    }
    final id = _uuid.v4();
    final path = '$_userId/$id';
    final mime = sniffImageMime(bytes);
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );
    try {
      await _client.from(_table).insert({
        'id': id,
        'user_id': _userId,
        'kind': 'image',
        'storage_path': path,
        'mime_type': mime,
        'size_bytes': bytes.length,
      });
    } catch (_) {
      // Don't leave an orphan object that no row points at.
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
    await _prune();
  }

  Future<Uint8List> downloadImage(ClipboardItem item) =>
      _client.storage.from(_bucket).download(item.storagePath!);

  Future<void> delete(ClipboardItem item) async {
    if (item.storagePath != null) {
      try {
        await _client.storage.from(_bucket).remove([item.storagePath!]);
      } catch (e) {
        debugPrint('Could not remove clipboard image: $e');
      }
    }
    await _client.from(_table).delete().eq('id', item.id);
  }

  /// Drops everything past the latest [keep] items. Never throws: the
  /// send already worked and the next one will prune again.
  Future<void> _prune() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .range(keep, keep + 49);
      for (final row in rows) {
        await delete(ClipboardItem.fromJson(row));
      }
    } catch (e) {
      debugPrint('Clipboard prune failed: $e');
    }
  }

  static String sniffImageMime(Uint8List b) {
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
    if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
      return 'image/gif';
    }
    if (b.length > 11 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42) {
      return 'image/webp';
    }
    return 'image/png';
  }
}
