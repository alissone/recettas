import 'exercise.dart';
import 'gym_entry.dart';

/// Every session ever logged for a single exercise, newest first, plus
/// the aggregates the history screens show.
///
/// Built client-side from the whole training log (see
/// SupabaseService.getAllGymEntries): the log is one row per exercise per
/// day, so even years of training is a few thousand rows - far cheaper to
/// group here than to run a query per exercise.
class ExerciseLog {
  final Exercise exercise;

  /// Newest session first.
  final List<GymEntry> entries;

  const ExerciseLog({required this.exercise, required this.entries});

  int get sessions => entries.length;

  GymEntry get lastEntry => entries.first;
  DateTime get lastDate => DateTime.parse(entries.first.entryDate);
  DateTime get firstDate => DateTime.parse(entries.last.entryDate);

  /// Sessions carrying a weight, oldest first. Bodyweight exercises have
  /// none, and the weight chart falls back to a note instead.
  List<GymEntry> get weighted => entries.reversed
      .where((e) => e.weight != null && e.weight! > 0)
      .toList();

  /// Heaviest session on record; null for bodyweight-only exercises.
  GymEntry? get prEntry {
    GymEntry? best;
    for (final entry in entries) {
      final weight = entry.weight;
      if (weight == null || weight <= 0) continue;
      if (best == null || weight > best.weight!) best = entry;
    }
    return best;
  }

  double? get prWeight => prEntry?.weight;

  /// Heaviest single session's estimated one-rep max, by the Epley
  /// formula (w * (1 + reps/30)). Useful because a heavy set of 3 and a
  /// lighter set of 12 aren't otherwise comparable.
  double? get bestOneRepMax {
    double? best;
    for (final entry in entries) {
      final weight = entry.weight;
      if (weight == null || weight <= 0) continue;
      final estimate = weight * (1 + entry.reps / 30);
      if (best == null || estimate > best) best = estimate;
    }
    return best;
  }

  double get totalVolume =>
      entries.fold<double>(0, (sum, e) => sum + e.volume);

  double get bestVolume =>
      entries.fold<double>(0, (m, e) => e.volume > m ? e.volume : m);

  /// Weight of the most recent weighted session minus the first, i.e. how
  /// much heavier the exercise got. Null when there are fewer than two
  /// weighted sessions to compare.
  double? get weightProgress {
    final weightedEntries = weighted;
    if (weightedEntries.length < 2) return null;
    return weightedEntries.last.weight! - weightedEntries.first.weight!;
  }

  /// Groups a flat log into one [ExerciseLog] per exercise, newest
  /// session first within each and most recently trained first overall.
  /// Rows whose exercise no longer exists in the catalog are dropped -
  /// there is nothing to show for them.
  static List<ExerciseLog> group(List<GymEntry> all) {
    final byExercise = <String, List<GymEntry>>{};
    final exercises = <String, Exercise>{};
    for (final entry in all) {
      byExercise.putIfAbsent(entry.exerciseId, () => []).add(entry);
      final exercise = entry.exercise;
      if (exercise != null) exercises[entry.exerciseId] = exercise;
    }

    final logs = <ExerciseLog>[];
    for (final group in byExercise.entries) {
      final exercise = exercises[group.key];
      if (exercise == null) continue;
      final entries = group.value
        ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
      logs.add(ExerciseLog(exercise: exercise, entries: entries));
    }
    logs.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return logs;
  }
}
