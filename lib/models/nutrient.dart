/// Broad grouping used to split the nutrition chart into readable
/// sections - 62 nutrients on one axis is unusable.
enum NutrientCategory {
  macronutrient,
  vitamin,
  mineral,
  aminoAcid,
  fattyAcid,
  sugar,
  sterol,
  phytochemical,
  other,
}

enum NutrientUnit {
  kcal,
  kj,
  g,
  mg,
  ug,
  iu,
  l,
  ml,
  percent,
}

/// Every nutrient the app can track. The `.name` of each value is stored
/// verbatim as public.nutrients.id, so ids round-trip with no conversion
/// table. Adding a value here means adding the matching catalog row.
enum NutrientId {
  // Energy
  calories,
  kilojoules,

  // Macronutrients
  protein,
  carbohydrates,
  fat,
  water,
  alcohol,

  // Carb breakdown
  fiber,
  solubleFiber,
  insolubleFiber,
  sugar,
  addedSugar,
  starch,

  // Fat breakdown
  saturatedFat,
  monounsaturatedFat,
  polyunsaturatedFat,
  transFat,
  cholesterol,

  omega3,
  omega6,

  epa,
  dha,
  ala,

  // Protein breakdown
  tryptophan,
  threonine,
  isoleucine,
  leucine,
  lysine,
  methionine,
  phenylalanine,
  valine,
  histidine,

  // Vitamins
  vitaminA,
  vitaminB1,
  vitaminB2,
  vitaminB3,
  vitaminB5,
  vitaminB6,
  vitaminB7,
  vitaminB9,
  vitaminB12,
  vitaminC,
  vitaminD,
  vitaminE,
  vitaminK,

  // Minerals
  calcium,
  iron,
  magnesium,
  phosphorus,
  potassium,
  sodium,
  zinc,
  copper,
  manganese,
  selenium,
  iodine,
  chromium,
  molybdenum,
  fluoride,
  chloride,

  // Other
  caffeine,
  choline,
}

/// Display suffix for each unit. NutrientUnit.name is what the database
/// stores; these are only ever shown to the user.
const Map<NutrientUnit, String> kNutrientUnitLabels = {
  NutrientUnit.kcal: 'kcal',
  NutrientUnit.kj: 'kJ',
  NutrientUnit.g: 'g',
  NutrientUnit.mg: 'mg',
  NutrientUnit.ug: 'µg',
  NutrientUnit.iu: 'UI',
  NutrientUnit.l: 'L',
  NutrientUnit.ml: 'ml',
  NutrientUnit.percent: '%',
};

/// Section headers on the nutrition screen.
const Map<NutrientCategory, String> kNutrientCategoryLabels = {
  NutrientCategory.macronutrient: 'Macronutrientes',
  NutrientCategory.vitamin: 'Vitaminas',
  NutrientCategory.mineral: 'Minerais',
  NutrientCategory.aminoAcid: 'Aminoácidos',
  NutrientCategory.fattyAcid: 'Ácidos graxos',
  NutrientCategory.sugar: 'Açúcares',
  NutrientCategory.sterol: 'Esteróis',
  NutrientCategory.phytochemical: 'Fitoquímicos',
  NutrientCategory.other: 'Outros',
};

final Map<String, NutrientId> _nutrientIdsByName = {
  for (final id in NutrientId.values) id.name: id,
};

/// Looks up a nutrient id coming from the database. Returns null for ids
/// the app does not know, so a catalog row added in SQL before the enum
/// caught up is skipped instead of being counted as another nutrient.
NutrientId? nutrientIdFromName(String? name) =>
    name == null ? null : _nutrientIdsByName[name];

/// A nutrient's identity plus, when it belongs to a food or a day's
/// total, how much of it there is.
class Nutrient {
  final NutrientId id;
  final String name;
  final NutrientCategory category;
  final NutrientUnit unit;
  final double amount;

  /// Display order, straight from public.nutrients.sort_order.
  final int sortOrder;

  /// Highlighted on the "Hábitos" summary card.
  final bool isPrimary;

  const Nutrient({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.amount = 0,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  String get unitLabel => kNutrientUnitLabels[unit] ?? unit.name;

  Nutrient copyWith({double? amount}) {
    return Nutrient(
      id: id,
      name: name,
      category: category,
      unit: unit,
      amount: amount ?? this.amount,
      sortOrder: sortOrder,
      isPrimary: isPrimary,
    );
  }

  /// A row of the public.nutrients catalog. Returns null when the id is
  /// unknown to [NutrientId] - this is a plain static rather than a
  /// factory because a factory cannot return null, and the usual
  /// `orElse` fallback would silently attribute the row to the wrong
  /// nutrient and corrupt every total.
  static Nutrient? fromJson(Map<String, dynamic> json) {
    final id = nutrientIdFromName(json['id']);
    if (id == null) return null;
    return Nutrient(
      id: id,
      name: json['name'] ?? id.name,
      category: NutrientCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => NutrientCategory.other,
      ),
      unit: NutrientUnit.values.firstWhere(
        (u) => u.name == json['unit'],
        orElse: () => NutrientUnit.g,
      ),
      sortOrder: json['sort_order'] ?? 0,
      isPrimary: json['is_primary'] ?? false,
    );
  }
}

/// Formats an amount with a sensible number of decimals: micrograms and
/// calories read better whole, grams to one decimal, tiny values to two.
String formatNutrientAmount(double value) {
  if (value.abs() >= 100) return value.round().toString();
  if (value.abs() >= 10) return value.toStringAsFixed(1);
  if (value.abs() >= 1) return value.toStringAsFixed(1);
  if (value == 0) return '0';
  return value.toStringAsFixed(2);
}
