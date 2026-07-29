import 'nutrient.dart';

/// A catalogued food. Nutrient values are stored per [baseAmount] of
/// [baseUnit] - usually 100 g, but 100 ml for liquids. No ml/g density
/// conversion happens anywhere: the pair is a divisor plus a label.
class Food {
  final String id;

  /// Null for the shared catalog seeded in SQL.
  final String? userId;
  final String name;
  final String? brand;
  final double baseAmount;

  /// 'g' or 'ml'.
  final String baseUnit;
  final String? imagePath;

  /// Values per [baseAmount], keyed by nutrient.
  final Map<NutrientId, Nutrient> nutrients;

  const Food({
    required this.id,
    this.userId,
    required this.name,
    this.brand,
    this.baseAmount = 100,
    this.baseUnit = 'g',
    this.imagePath,
    this.nutrients = const {},
  });

  /// How much of [nutrient] is in one [baseAmount] of this food.
  double get(NutrientId nutrient) => nutrients[nutrient]?.amount ?? 0;

  /// "Arroz branco" or "Arroz branco · Tio João".
  String get label => brand == null || brand!.isEmpty ? name : '$name · $brand';

  /// Expects the embedded child rows produced by
  /// `.select('*, food_nutrients(nutrient_id, amount)')`. [catalog] maps
  /// each id to its name, category and unit; rows whose nutrient_id is
  /// missing from the catalog are skipped.
  factory Food.fromJson(
      Map<String, dynamic> json, Map<NutrientId, Nutrient> catalog) {
    final nutrients = <NutrientId, Nutrient>{};
    final rows = json['food_nutrients'];
    if (rows is List) {
      for (final row in rows) {
        final id = nutrientIdFromName(row['nutrient_id']);
        final template = id == null ? null : catalog[id];
        if (id == null || template == null) continue;
        nutrients[id] = template.copyWith(
          amount: double.tryParse(row['amount'].toString()) ?? 0,
        );
      }
    }
    return Food(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'] ?? '',
      brand: json['brand'],
      baseAmount: double.tryParse(json['base_amount'].toString()) ?? 100,
      baseUnit: json['base_unit'] ?? 'g',
      imagePath: json['image_path'],
      nutrients: nutrients,
    );
  }
}

/// One portion eaten on one day.
class FoodEntry {
  final String id;
  final String userId;

  /// Data in YYYY-MM-DD format (matches the `date` column).
  final String entryDate;
  final Food food;

  /// In the food's [Food.baseUnit].
  final double amount;
  final DateTime? createdAt;

  const FoodEntry({
    required this.id,
    required this.userId,
    required this.entryDate,
    required this.food,
    required this.amount,
    this.createdAt,
  });

  /// How much of [id] this portion contributed.
  double nutrient(NutrientId id) =>
      food.get(id) * amount / food.baseAmount;

  /// "180 g".
  String get amountLabel =>
      '${formatNutrientAmount(amount)} ${food.baseUnit}';

  /// Expects `.select('*, food:foods(*, food_nutrients(...)))'`.
  factory FoodEntry.fromJson(
      Map<String, dynamic> json, Map<NutrientId, Nutrient> catalog) {
    return FoodEntry(
      id: json['id'],
      userId: json['user_id'],
      entryDate: json['entry_date'] ?? '',
      food: Food.fromJson(json['food'] ?? const {}, catalog),
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

/// Sums every nutrient across [entries], scaling each food by the amount
/// eaten. Nutrients absent from a food simply don't contribute.
Map<NutrientId, double> calculateTotals(List<FoodEntry> entries) {
  final totals = <NutrientId, double>{};
  for (final entry in entries) {
    if (entry.food.baseAmount <= 0) continue;
    for (final nutrient in entry.food.nutrients.values) {
      totals[nutrient.id] = (totals[nutrient.id] ?? 0) +
          nutrient.amount * entry.amount / entry.food.baseAmount;
    }
  }
  return totals;
}
