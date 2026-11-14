import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/job_reply.dart';

/// Recruiter replies written by Claude. The app only inserts a request
/// row; the transcriber worker on the PC (transcriber/worker.py) picks it
/// up, calls Claude and fills in subject/reply/notes.
class JobReplyRepository {
  JobReplyRepository._();

  static final JobReplyRepository instance = JobReplyRepository._();

  static const _table = 'job_replies';

  /// How many past requests the screen shows.
  static const historySize = 30;

  SupabaseClient get _client => Supabase.instance.client;
  String get _userId => _client.auth.currentUser!.id;

  /// Latest requests, newest first, updating live as the worker fills them.
  Stream<List<JobReply>> watch() => _client
      .from(_table)
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(historySize)
      .map((rows) => rows.map(JobReply.fromJson).toList());

  Future<void> request({
    required JobReplyChannel channel,
    required String message,
    String? jobDescription,
    String? instructions,
  }) async {
    await _client.from(_table).insert({
      'user_id': _userId,
      'channel': channel.value,
      'message': message.trim(),
      'job_description': _blankToNull(jobDescription),
      'instructions': _blankToNull(instructions),
      'status': 'requested',
    });
  }

  /// Asks for a new version, optionally with different instructions.
  Future<void> redo(String id, {String? instructions}) async {
    await _client.from(_table).update({
      'instructions': _blankToNull(instructions),
      'status': 'requested',
      'error_message': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Stops a pending request; the worker drops its result if it's mid-way.
  Future<void> cancel(String id) async {
    await _client.from(_table).update({
      'status': 'error',
      'error_message': 'Cancelado',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) =>
      _client.from(_table).delete().eq('id', id);

  static String? _blankToNull(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}
