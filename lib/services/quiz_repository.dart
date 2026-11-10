import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz.dart';

/// Quizzes and attempts. Quizzes come from two places:
///
///  * the `quizzes` table (migration 044), filled by
///    scripts/upload_quiz.py - the list selects only the summary columns
///    and [load] fetches `content` on demand;
///  * JSON files bundled under assets/quizzes/ (each a quiz object or an
///    array of them), so there is something to play before anything is
///    uploaded. A row in the table with the same id replaces the bundled
///    copy.
///
/// No dart:io, so the web build can use it too.
class QuizRepository {
  QuizRepository._();

  static final QuizRepository instance = QuizRepository._();

  static const _quizzes = 'quizzes';
  static const _attempts = 'quiz_attempts';
  static const _assetDir = 'assets/quizzes/';

  SupabaseClient get _client => Supabase.instance.client;

  Map<String, Quiz>? _bundled;

  /// Full quizzes already fetched, so reopening one is instant.
  final _cache = <String, Quiz>{};

  Future<Map<String, Quiz>> _loadBundled() async {
    if (_bundled != null) return _bundled!;
    final result = <String, Quiz>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final files = manifest.listAssets().where(
        (p) => p.startsWith(_assetDir) && p.endsWith('.json'),
      );
      for (final path in files) {
        final decoded = jsonDecode(await rootBundle.loadString(path));
        final list = decoded is List ? decoded : [decoded];
        for (final item in list) {
          final quiz = Quiz.fromJson(item as Map<String, dynamic>);
          result[quiz.id] = quiz;
        }
      }
    } catch (e) {
      debugPrint('Bundled quizzes failed to load: $e');
    }
    return _bundled = result;
  }

  /// Every quiz, newest uploads first, then the bundled ones. Throws
  /// only when there is nothing at all to show.
  Future<List<QuizSummary>> list() async {
    final bundled = await _loadBundled();
    List<QuizSummary> remote = const [];
    Object? remoteError;
    try {
      final rows = await _client
          .from(_quizzes)
          .select('id, title, topic, description, question_count, created_at')
          .order('created_at', ascending: false);
      remote = rows.map(QuizSummary.fromRow).toList();
    } catch (e) {
      // Most likely migration 044 hasn't been run yet.
      debugPrint('Quiz list from Supabase failed: $e');
      remoteError = e;
    }
    if (remote.isEmpty && bundled.isEmpty && remoteError != null) {
      throw remoteError;
    }
    final remoteIds = remote.map((q) => q.id).toSet();
    return [
      ...remote,
      for (final quiz in bundled.values)
        if (!remoteIds.contains(quiz.id))
          QuizSummary(
            id: quiz.id,
            title: quiz.title,
            topic: quiz.topic,
            description: quiz.description,
            questionCount: quiz.questions.length,
            bundled: true,
          ),
    ];
  }

  /// The whole quiz, questions included.
  Future<Quiz> load(QuizSummary summary) async {
    final cached = _cache[summary.id];
    if (cached != null) return cached;
    final Quiz quiz;
    if (summary.bundled) {
      quiz = (await _loadBundled())[summary.id]!;
    } else {
      final row = await _client
          .from(_quizzes)
          .select('id, content')
          .eq('id', summary.id)
          .single();
      quiz = Quiz.fromJson(
        row['content'] as Map<String, dynamic>,
        id: row['id'] as String,
      );
    }
    return _cache[summary.id] = quiz;
  }

  /// This user's attempts at [quizId], oldest first.
  Future<List<QuizAttempt>> attempts(String quizId) async {
    final rows = await _client
        .from(_attempts)
        .select('quiz_id, answers, duration_seconds, created_at')
        .eq('quiz_id', quizId)
        .order('created_at');
    return rows.map(QuizAttempt.fromRow).toList();
  }

  /// How many times this user has taken each quiz, for the list badges.
  /// Empty when the table isn't there yet.
  Future<Map<String, int>> attemptCounts() async {
    try {
      final rows = await _client.from(_attempts).select('quiz_id');
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['quiz_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('Quiz attempt counts failed: $e');
      return const {};
    }
  }

  Future<void> saveAttempt({
    required String quizId,
    required String answers,
    int? durationSeconds,
  }) async {
    final user = _client.auth.currentUser!;
    await _client.from(_attempts).insert({
      'quiz_id': quizId,
      'user_id': user.id,
      'user_email': user.email,
      'answers': answers,
      'duration_seconds': durationSeconds,
    });
  }
}
