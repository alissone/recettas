import 'exercise.dart';

// Based on MuscleWiki Exercise Database

/// One exercise done on one day: [sets] x [reps] at a single [weight].
/// Drop sets are out of scope, so the weight applies to every set.
class GymEntry {
  final String id;
  final String userId;

  /// Data in YYYY-MM-DD format (matches the `date` column).
  final String entryDate;
  final String exerciseId;
  final int sets;
  final int reps;

  /// Kilograms; null for bodyweight work.
  final double? weight;
  final String? notes;

  /// Populated when the row was fetched with the embedded join.
  final Exercise? exercise;
  final DateTime? createdAt;

  const GymEntry({
    required this.id,
    required this.userId,
    required this.entryDate,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.weight,
    this.notes,
    this.exercise,
    this.createdAt,
  });

  /// Total load moved, in kg. Zero for bodyweight work.
  double get volume => sets * reps * (weight ?? 0);

  /// "3 x 12".
  String get setsLabel => '$sets x $reps';

  factory GymEntry.fromJson(Map<String, dynamic> json) {
    return GymEntry(
      id: json['id'],
      userId: json['user_id'],
      entryDate: json['entry_date'] ?? '',
      exerciseId: json['exercise_id'],
      sets: json['sets'] ?? 1,
      reps: json['reps'] ?? 1,
      weight: json['weight'] != null
          ? double.tryParse(json['weight'].toString())
          : null,
      notes: json['notes'],
      exercise: json['exercise'] != null
          ? Exercise.fromJson(json['exercise'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
