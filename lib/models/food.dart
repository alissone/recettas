import 'nutrient.dart';
import 'recipe.dart';

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

/// A food sold in a fixed size: the small and the large pack of the same
/// biscuits are the same [Food] - same values per 100 g - and differ only
/// in [amount]. Logging one is logging that many grams of the food.
class FoodPackage {
  final String id;

  /// Null for shared packages seeded in SQL.
  final String? userId;
  final String foodId;

  /// "Pacote pequeno". Optional: the weight alone already identifies it.
  final String? name;

  /// In the food's [Food.baseUnit].
  final double amount;

  const FoodPackage({
    required this.id,
    this.userId,
    required this.foodId,
    this.name,
    required this.amount,
  });

  /// "Pacote pequeno" when it was named, "140 g" when it wasn't.
  String labelFor(String baseUnit) => name != null && name!.isNotEmpty
      ? name!
      : '${formatNutrientAmount(amount)} $baseUnit';

  factory FoodPackage.fromJson(Map<String, dynamic> json) {
    return FoodPackage(
      id: json['id'],
      userId: json['user_id'],
      foodId: json['food_id'] ?? '',
      name: json['name'],
      amount: double.tryParse(json['amount'].toString()) ?? 0,
    );
  }
}

/// One portion eaten on one day.
class FoodEntry {
  final String id;
  final String userId;

  /// Data in YYYY-MM-DD format (matches the `date` column).
  final String entryDate;

  /// What was eaten, always as a single ingredient: a recipe entry
  /// carries the recipe flattened by [Recipe.asFood].
  final Food food;

  /// Set when this entry logs a recipe rather than an ingredient - the
  /// same recipe the "Receitas" tab shows.
  final Recipe? recipe;

  /// Set when the amount was entered as "N packs of it". Display only -
  /// the nutrients come from [food] either way.
  final FoodPackage? package;

  /// In the food's [Food.baseUnit].
  final double amount;
  final DateTime? createdAt;

  const FoodEntry({
    required this.id,
    required this.userId,
    required this.entryDate,
    required this.food,
    this.recipe,
    this.package,
    required this.amount,
    this.createdAt,
  });

  /// How much of [id] this portion contributed.
  double nutrient(NutrientId id) => food.baseAmount <= 0
      ? 0
      : food.get(id) * amount / food.baseAmount;

  /// "180 g", or "2 x Pacote pequeno · 280 g" when it came from a
  /// package.
  String get amountLabel {
    final weight = '${formatNutrientAmount(amount)} ${food.baseUnit}';
    final pack = package;
    if (pack == null || pack.amount <= 0) return weight;
    return '${formatQuantity(amount / pack.amount)} × '
        '${pack.labelFor(food.baseUnit)} · $weight';
  }

  /// Expects `.select('*, food:foods(*, food_nutrients(...)),
  /// recipe:recipes(...), package:food_packages(*))'`. Rows carry
  /// either a food or a recipe, never both.
  factory FoodEntry.fromJson(
      Map<String, dynamic> json, Map<NutrientId, Nutrient> catalog) {
    final recipeJson = json['recipe'];
    final recipe = recipeJson is Map<String, dynamic>
        ? Recipe.fromJson(recipeJson, catalog)
        : null;
    final packageJson = json['package'];
    return FoodEntry(
      id: json['id'],
      userId: json['user_id'],
      entryDate: json['entry_date'] ?? '',
      food: recipe != null
          ? recipe.asFood()
          : Food.fromJson(json['food'] ?? const {}, catalog),
      recipe: recipe,
      package: packageJson is Map<String, dynamic>
          ? FoodPackage.fromJson(packageJson)
          : null,
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
