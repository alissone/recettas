import 'exercise.dart';
import 'gym_entry.dart';

/// Every set group ever logged for a single exercise, newest first, plus
/// the aggregates the history screens show.
///
/// Built client-side from the whole training log (see
/// SupabaseService.getAllGymEntries): a day can hold several set groups
/// for the same exercise (e.g. a top set plus drop sets), but even years
/// of training is a few thousand rows - far cheaper to group here than to
/// run a query per exercise.
class ExerciseLog {
  final Exercise exercise;

  /// Newest set group first; several can share a day.
  final List<GymEntry> entries;

  const ExerciseLog({required this.exercise, required this.entries});

  /// Entries grouped by day - a day can hold several set groups (e.g. a
  /// top set plus drop sets), so "sessions" and "best day" are counted
  /// per day rather than per row.
  Map<DateTime, List<GymEntry>> get byDay {
    final map = <DateTime, List<GymEntry>>{};
    for (final entry in entries) {
      map.putIfAbsent(DateTime.parse(entry.entryDate), () => []).add(entry);
    }
    return map;
  }

  int get sessions => byDay.length;

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

  /// Heaviest single day's total volume - a day's sets are summed first
  /// since a day can hold several set groups.
  double get bestVolume => byDay.values.fold<double>(0, (m, dayEntries) {
        final dayVolume =
            dayEntries.fold<double>(0, (sum, e) => sum + e.volume);
        return dayVolume > m ? dayVolume : m;
      });

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
      // Same-day set groups break the tie by creation order (newest
      // first) so the sort is deterministic - a day can hold several now.
      final entries = group.value
        ..sort((a, b) {
          final byDate = b.entryDate.compareTo(a.entryDate);
          if (byDate != 0) return byDate;
          final aCreated = a.createdAt;
          final bCreated = b.createdAt;
          if (aCreated == null || bCreated == null) return 0;
          return bCreated.compareTo(aCreated);
        });
      logs.add(ExerciseLog(exercise: exercise, entries: entries));
    }
    logs.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return logs;
  }
}
