import 'nutrient.dart';

/// A named set of daily targets ("Adulto - VD ANVISA", "Gestante",
/// "Cetogênica"). Sets with a null userId are shared presets meant to be
/// copied, not edited.
class NutrientRecommendationSet {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final DateTime? createdAt;

  const NutrientRecommendationSet({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.createdAt,
  });

  bool get isShared => userId == null;

  factory NutrientRecommendationSet.fromJson(Map<String, dynamic> json) {
    return NutrientRecommendationSet(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'] ?? '',
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

/// The daily target for one nutrient inside a set. [unit] is stored with
/// the target rather than read from the catalog, so a target can use a
/// different unit than the food data.
class NutrientRecommendation {
  final String id;
  final String setId;
  final NutrientId nutrient;
  final double amount;
  final NutrientUnit unit;

  const NutrientRecommendation({
    required this.id,
    required this.setId,
    required this.nutrient,
    required this.amount,
    required this.unit,
  });

  /// Null when the row names a nutrient this build doesn't know - see
  /// [Nutrient.fromJson] for why the unknown case is skipped rather than
  /// defaulted.
  static NutrientRecommendation? fromJson(Map<String, dynamic> json) {
    final id = nutrientIdFromName(json['nutrient_id']);
    if (id == null) return null;
    return NutrientRecommendation(
      id: json['id'],
      setId: json['set_id'],
      nutrient: id,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      unit: NutrientUnit.values.firstWhere(
        (u) => u.name == json['unit'],
        orElse: () => NutrientUnit.g,
      ),
    );
  }
}
