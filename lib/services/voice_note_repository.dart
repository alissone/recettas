import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/voice_note.dart';
import 'local_db.dart';

/// Voice notes: recorded to a local file, queued in SQLite, and uploaded
/// to the "voice-notes" bucket whenever the server is reachable. The
/// local WhisperX worker (transcriber/worker.py) picks up each row,
/// transcribes it and deletes the audio; summaries are requested by
/// flagging the row and also filled in by the worker.
class VoiceNoteRepository {
  VoiceNoteRepository._();

  static final VoiceNoteRepository instance = VoiceNoteRepository._();

  static const _uuid = Uuid();
  static const _bucket = 'voice-notes';
  static const _table = 'voice_notes';
  static const _retryDelay = Duration(seconds: 30);

  /// Recordings still on this device; drives the badge and the
  /// "aguardando envio" rows.
  final ValueNotifier<int> pendingCount = ValueNotifier(0);

  bool _uploading = false;
  bool _uploadAgain = false;
  Timer? _retryTimer;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<void> init() async {
    _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        uploadPending();
      }
    });
    uploadPending();
  }

  // --- Recording ---

  /// Where a new recording should be written; [id] doubles as the note id.
  Future<({String id, String path})> newRecordingPath() async {
    final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'voice_notes'));
    await dir.create(recursive: true);
    final id = _uuid.v4();
    return (id: id, path: p.join(dir.path, '$id.m4a'));
  }

  /// Queue a finished recording and try to upload it right away.
  Future<void> addRecording(
      {required String id,
      required String filePath,
      required int durationSeconds}) async {
    final uid = _userId;
    if (uid == null) return;
    final db = await LocalDb.instance;
    await db.insert('voice_uploads', {
      'id': id,
      'user_id': uid,
      'file_path': filePath,
      'duration_seconds': durationSeconds,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _refreshPendingCount();
    uploadPending();
  }

  Future<List<PendingVoiceUpload>> getPendingUploads() async {
    final uid = _userId;
    if (uid == null) return [];
    final db = await LocalDb.instance;
    final rows = await db.query('voice_uploads',
        where: 'user_id = ?', whereArgs: [uid], orderBy: 'recorded_at DESC');
    return rows.map(PendingVoiceUpload.fromDb).toList();
  }

  Future<void> discardPendingUpload(PendingVoiceUpload upload) async {
    final db = await LocalDb.instance;
    await db.delete('voice_uploads', where: 'id = ?', whereArgs: [upload.id]);
    await _deleteFile(upload.filePath);
    await _refreshPendingCount();
  }

  // --- Upload queue ---

  /// Upload every queued recording (oldest first). Safe to call any time;
  /// on a network failure it retries on its own.
  Future<void> uploadPending() async {
    if (_userId == null) return;
    if (_uploading) {
      _uploadAgain = true;
      return;
    }
    _uploading = true;
    _retryTimer?.cancel();
    try {
      final db = await LocalDb.instance;
      final rows = await db.query('voice_uploads',
          where: 'user_id = ?', whereArgs: [_userId], orderBy: 'recorded_at');
      for (final row in rows) {
        final upload = PendingVoiceUpload.fromDb(row);
        final file = File(upload.filePath);
        if (!await file.exists()) {
          // Nothing left to send (app data cleared?) - drop the entry.
          await db.delete('voice_uploads',
              where: 'id = ?', whereArgs: [upload.id]);
          continue;
        }
        await _upload(upload, row['user_id'] as String, file);
        await db.delete('voice_uploads',
            where: 'id = ?', whereArgs: [upload.id]);
        await _deleteFile(upload.filePath);
      }
    } catch (e) {
      debugPrint('Voice note upload failed, retrying: $e');
      _retryTimer = Timer(_retryDelay, uploadPending);
    } finally {
      _uploading = false;
      await _refreshPendingCount();
      if (_uploadAgain) {
        _uploadAgain = false;
        uploadPending();
      }
    }
  }

  Future<void> _upload(
      PendingVoiceUpload upload, String userId, File file) async {
    final path = '$userId/${upload.id}.m4a';
    // upsert: a retry after a half-finished attempt overwrites it.
    await _client.storage.from(_bucket).upload(
          path,
          file,
          fileOptions:
              const FileOptions(contentType: 'audio/mp4', upsert: true),
        );
    // upsert on the row too, keyed by the id generated at record time.
    await _client.from(_table).upsert({
      'id': upload.id,
      'user_id': userId,
      'audio_path': path,
      'duration_seconds': upload.durationSeconds,
      'status': 'queued',
      'recorded_at': upload.recordedAt.toIso8601String(),
    });
  }

  Future<void> _refreshPendingCount() async {
    pendingCount.value = (await getPendingUploads()).length;
  }

  Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  // --- Server notes ---

  Future<List<VoiceNote>> getNotes() async {
    final data = await _client
        .from(_table)
        .select()
        .order('recorded_at', ascending: false);
    return data.map<VoiceNote>(VoiceNote.fromJson).toList();
  }

  Future<void> requestSummary(String id) async {
    await _client.from(_table).update({
      'summary_status': 'requested',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> retryTranscription(String id) async {
    await _client.from(_table).update({
      'status': 'queued',
      'error_message': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteNote(VoiceNote note) async {
    if (note.audioPath != null) {
      await _client.storage.from(_bucket).remove([note.audioPath!]);
    }
    await _client.from(_table).delete().eq('id', note.id);
  }
}
