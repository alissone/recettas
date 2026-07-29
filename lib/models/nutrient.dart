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
  carotenoid,
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
  ash,

  // Carb breakdown
  fiber,
  solubleFiber,
  insolubleFiber,
  starch,
  sugar,
  addedSugar,
  monosaccharides,
  glucose,
  fructose,
  galactose,
  sucrose,
  lactose,
  maltose,

  // Fat breakdown
  saturatedFat,
  monounsaturatedFat,
  polyunsaturatedFat,
  transFat,

  omega3,
  omega6,

  // Sterols
  cholesterol,
  stigmasterol,
  campesterol,
  betaSitosterol,

  transMonoenoicFat,
  transPolyenoicFat,

  // Saturated chains
  butyricAcid,
  caproicAcid,
  caprylicAcid,
  capricAcid,
  lauricAcid,
  myristicAcid,
  palmiticAcid,
  heptadecanoicAcid,
  stearicAcid,
  arachidicAcid,

  // Monounsaturated chains
  palmitoleicAcid,
  palmitoleicAcidCis,
  oleicAcid,
  oleicAcidCis,
  oleicAcidTrans,
  gadoleicAcid,
  erucicAcid,

  // Polyunsaturated chains
  linoleicAcid,
  linoleicAcidCis,
  conjugatedLinoleicAcid,
  linoleicAcidIsomers,
  ala,
  parinaricAcid,
  arachidonicAcid,
  epa,
  dpa,
  dha,

  // Protein breakdown
  tryptophan,
  threonine,
  isoleucine,
  leucine,
  lysine,
  methionine,
  cysteine,
  phenylalanine,
  tyrosine,
  valine,
  arginine,
  histidine,
  alanine,
  asparticAcid,
  glutamicAcid,
  glycine,
  proline,
  serine,

  // Vitamins
  vitaminA,
  retinol,
  vitaminAIu,
  vitaminB1,
  vitaminB2,
  vitaminB3,
  vitaminB5,
  vitaminB6,
  vitaminB7,
  vitaminB9,
  folicAcid,
  foodFolate,
  folateDfe,
  vitaminB12,
  addedVitaminB12,
  vitaminC,
  vitaminD,
  vitaminD2,
  vitaminD3,
  vitaminDIu,
  vitaminE,
  addedVitaminE,
  betaTocopherol,
  gammaTocopherol,
  deltaTocopherol,
  alphaTocotrienol,
  betaTocotrienol,
  gammaTocotrienol,
  deltaTocotrienol,
  vitaminK,
  dihydrophylloquinone,

  // Carotenoids
  betaCarotene,
  alphaCarotene,
  betaCryptoxanthin,
  lycopene,
  luteinZeaxanthin,

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
  theobromine,
  choline,
  betaine,
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
  NutrientCategory.carotenoid: 'Carotenoides',
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

/// Formats an amount with a sensible number of decimals: large values
/// read better whole, grams to one decimal, and traces to three - source
/// tables report copper at 0.031 mg and manganese at 0.009 mg, which two
/// decimals would round away to noise.
String formatNutrientAmount(double value) {
  if (value == 0) return '0';
  final abs = value.abs();
  if (abs >= 100) return value.round().toString();
  if (abs >= 1) return value.toStringAsFixed(1);
  if (abs >= 0.1) return value.toStringAsFixed(2);
  return value.toStringAsFixed(3);
}
