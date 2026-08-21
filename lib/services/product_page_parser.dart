import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:uuid/uuid.dart';

import '../models/nutrient.dart';
import 'product_page_extractor.dart';

/// One recognised nutrient row from a product's nutrition table.
class ParsedNutritionRow {
  final NutrientId nutrientId;
  final double amount;
  final String label;

  const ParsedNutritionRow({
    required this.nutrientId,
    required this.amount,
    required this.label,
  });
}

/// Mirrors the (base_amount, base_unit, rows, unknown, skipped) tuple
/// scripts/product_page_to_sql.py's parse_nutrition_table returns.
class ParsedProduct {
  final double baseAmount;
  final String baseUnit;
  final List<ParsedNutritionRow> rows;
  final List<String> unknownLabels;
  final List<String> skippedNotes;

  const ParsedProduct({
    required this.baseAmount,
    required this.baseUnit,
    required this.rows,
    required this.unknownLabels,
    required this.skippedNotes,
  });
}

/// Dart port of scripts/product_page_to_sql.py, sourced from the DOM data
/// an [ExtractedPage] carries (no markdown dump exists in-app). Never
/// guesses: a nutrient label it doesn't recognise, or a unit it can't
/// convert, is reported and left out rather than mapped to something close.
class ProductPageParser {
  ProductPageParser._();

  /// Same namespace scripts/product_page_to_sql.py uses, so the id shape
  /// matches - see [foodUuidFor] for why byte-parity with Python doesn't
  /// otherwise matter.
  static const String foodNamespace = '6f9619ff-8b86-d011-b42d-00c04fc964ff';

  static final RegExp _valueCellRe = RegExp(
    r'^(?<value>-?\d+(?:[.,]\d+)?)\s*(?<unit>g|mg|mcg|µg|ug|kcal|kj|iu|ui|ml|l|%)$',
    caseSensitive: false,
  );

  static final RegExp _portionLineRe = RegExp(
    r'Por[çc][ãa]o\s+de\s*(?<amount>\d+(?:[.,]\d+)?)\s*(?<unit>g|ml)',
    caseSensitive: false,
  );

  static final RegExp _codeLineRe = RegExp(r'C[óo]d\.?:\s*(\S+)');

  static final RegExp _nutritionSectionRe = RegExp(
    r'Tabela\s+nutricional',
    caseSensitive: false,
  );

  static const Map<String, NutrientUnit> _reportUnits = {
    'g': NutrientUnit.g,
    'mg': NutrientUnit.mg,
    'mcg': NutrientUnit.ug,
    'µg': NutrientUnit.ug,
    'ug': NutrientUnit.ug,
    'kcal': NutrientUnit.kcal,
    'kj': NutrientUnit.kj,
    'iu': NutrientUnit.iu,
    'ui': NutrientUnit.iu,
    'ml': NutrientUnit.ml,
    'l': NutrientUnit.l,
    '%': NutrientUnit.percent,
  };

  /// Grams per unit, for the only conversions worth doing automatically.
  static const Map<NutrientUnit, double> _massInGrams = {
    NutrientUnit.g: 1.0,
    NutrientUnit.mg: 1e-3,
    NutrientUnit.ug: 1e-6,
  };

  static const Map<String, NutrientId> _nameToId = {
    // Macronutrients
    'carboidratos': NutrientId.carbohydrates,
    'carboidrato': NutrientId.carbohydrates,
    'proteinas': NutrientId.protein,
    'proteina': NutrientId.protein,
    'gorduras totais': NutrientId.fat,
    'gorduras saturadas': NutrientId.saturatedFat,
    'gorduras trans': NutrientId.transFat,
    'gorduras monoinsaturadas': NutrientId.monounsaturatedFat,
    'gorduras poliinsaturadas': NutrientId.polyunsaturatedFat,
    'gorduras poli-insaturadas': NutrientId.polyunsaturatedFat,
    'fibra alimentar': NutrientId.fiber,
    'sodio': NutrientId.sodium,
    'colesterol': NutrientId.cholesterol,
    'amido': NutrientId.starch,
    'alcool': NutrientId.alcohol,
    'agua': NutrientId.water,
    'cinzas': NutrientId.ash,

    // Sugars
    'acucares totais': NutrientId.sugar,
    'acucares adicionados': NutrientId.addedSugar,
    'lactose': NutrientId.lactose,
    'sacarose': NutrientId.sucrose,
    'glicose': NutrientId.glucose,
    'frutose': NutrientId.fructose,
    'galactose': NutrientId.galactose,
    'maltose': NutrientId.maltose,

    // Fatty acids
    'omega 3': NutrientId.omega3,
    'omega-3': NutrientId.omega3,
    'omega 6': NutrientId.omega6,
    'omega-6': NutrientId.omega6,
    'epa': NutrientId.epa,
    'dha': NutrientId.dha,
    'ala': NutrientId.ala,

    // Minerals
    'calcio': NutrientId.calcium,
    'ferro': NutrientId.iron,
    'magnesio': NutrientId.magnesium,
    'fosforo': NutrientId.phosphorus,
    'potassio': NutrientId.potassium,
    'zinco': NutrientId.zinc,
    'cobre': NutrientId.copper,
    'manganes': NutrientId.manganese,
    'selenio': NutrientId.selenium,
    'iodo': NutrientId.iodine,
    'cromo': NutrientId.chromium,
    'molibdenio': NutrientId.molybdenum,
    'fluor': NutrientId.fluoride,
    'cloreto': NutrientId.chloride,

    // Vitamins
    'vitamina c': NutrientId.vitaminC,
    'tiamina': NutrientId.vitaminB1,
    'vitamina b1': NutrientId.vitaminB1,
    'riboflavina': NutrientId.vitaminB2,
    'vitamina b2': NutrientId.vitaminB2,
    'niacina': NutrientId.vitaminB3,
    'vitamina b3': NutrientId.vitaminB3,
    'acido pantotenico': NutrientId.vitaminB5,
    'vitamina b5': NutrientId.vitaminB5,
    'vitamina b6': NutrientId.vitaminB6,
    'biotina': NutrientId.vitaminB7,
    'vitamina b7': NutrientId.vitaminB7,
    'acido folico': NutrientId.vitaminB9,
    'folato': NutrientId.vitaminB9,
    'vitamina b9': NutrientId.vitaminB9,
    'vitamina b12': NutrientId.vitaminB12,
    'vitamina e': NutrientId.vitaminE,
    'vitamina k': NutrientId.vitaminK,
    'colina': NutrientId.choline,

    // Other
    'cafeina': NutrientId.caffeine,
    'teobromina': NutrientId.theobromine,
  };

  /// Labels only distinguishable by the unit column, same ambiguity as in
  /// scripts/product_page_to_sql.py.
  static const Map<(String, NutrientUnit), NutrientId> _nameToIdByUnit = {
    ('valor energetico', NutrientUnit.kcal): NutrientId.calories,
    ('valor energetico', NutrientUnit.kj): NutrientId.kilojoules,
    ('vitamina a', NutrientUnit.ug): NutrientId.vitaminA,
    ('vitamina a', NutrientUnit.iu): NutrientId.vitaminAIu,
    ('vitamina d', NutrientUnit.ug): NutrientId.vitaminD,
    ('vitamina d', NutrientUnit.iu): NutrientId.vitaminDIu,
  };

  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
    'í': 'i', 'î': 'i', 'ì': 'i', 'ï': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ö': 'o',
    'ú': 'u', 'û': 'u', 'ù': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
    'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
    'É': 'E', 'Ê': 'E', 'È': 'E', 'Ë': 'E',
    'Í': 'I', 'Î': 'I', 'Ì': 'I', 'Ï': 'I',
    'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ò': 'O', 'Ö': 'O',
    'Ú': 'U', 'Û': 'U', 'Ù': 'U', 'Ü': 'U',
    'Ç': 'C', 'Ñ': 'N',
  };

  /// Substitute for Python's `unicodedata.normalize('NFD', …)` accent
  /// stripping - Dart's core SDK has no NFD decomposition, so this covers
  /// the Portuguese diacritics that actually show up in nutrition labels
  /// and product names instead of pulling in a package for full Unicode
  /// normalization. Doesn't need to byte-match Python: see [foodUuidFor].
  static String stripAccents(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_accentMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Accent-free, lowercase, single-spaced, no trailing punctuation.
  static String normalize(String text) {
    final lower = stripAccents(text).toLowerCase();
    final squashed = lower.replaceAll(RegExp(r'\s+'), ' ').trim();
    return squashed.replaceFirst(RegExp(r'[.:]+$'), '').trim();
  }

  static NutrientId? resolveId(String nameNorm, NutrientUnit unit) {
    return _nameToIdByUnit[(nameNorm, unit)] ?? _nameToId[nameNorm];
  }

  /// Mass-only conversion, mirrors convert_amount(). [error] is set instead
  /// of [amount] when the units can't be reconciled automatically.
  static ({double? amount, String? error}) convertAmount(
    double amount,
    NutrientUnit from,
    NutrientUnit to,
  ) {
    if (from == to) return (amount: amount, error: null);
    final fromGrams = _massInGrams[from];
    final toGrams = _massInGrams[to];
    if (fromGrams != null && toGrams != null) {
      return (amount: amount * fromGrams / toGrams, error: null);
    }
    return (
      amount: null,
      error: 'reportado em ${from.name}, catálogo espera ${to.name}',
    );
  }

  /// Scans every row of every table for a first cell normalizing to
  /// "marca" and returns the second cell. Replaces the markdown-only
  /// BRAND_ROW regex with the same "Marca row anywhere" semantics.
  static String? findBrand(List<List<List<String>>> tables) {
    for (final table in tables) {
      for (final row in table) {
        if (row.length < 2) continue;
        if (normalize(row[0]) == 'marca') {
          final brand = row[1].trim();
          return brand.isEmpty ? null : brand;
        }
      }
    }
    return null;
  }

  /// Display-only, never persisted - mirrors the script, where it only
  /// ends up in a SQL comment.
  static String? findCode(String bodyText) {
    return _codeLineRe.firstMatch(bodyText)?.group(1)?.trim();
  }

  /// Returns null when no recognisable "Tabela nutricional" section (a
  /// "Porção de N g|ml" line plus a matching table) is present, mirroring
  /// the Python function's None return for the same case.
  static ParsedProduct? parseNutritionTable(
    ExtractedPage page,
    Map<NutrientId, Nutrient> catalog,
  ) {
    final sectionMatch = _nutritionSectionRe.firstMatch(page.bodyText);
    if (sectionMatch == null) return null;
    final sectionText = page.bodyText.substring(sectionMatch.end);

    final portionMatch = _portionLineRe.firstMatch(sectionText);
    if (portionMatch == null) return null;
    final baseAmount = double.parse(
      portionMatch.namedGroup('amount')!.replaceAll(',', '.'),
    );
    final baseUnit = portionMatch.namedGroup('unit')!.toLowerCase();

    final table = _findNutritionTable(page.tables);
    if (table == null) return null;

    final rows = <ParsedNutritionRow>[];
    final seen = <NutrientId, String>{};
    final unknown = <String>[];
    final skipped = <String>[];

    for (final row in table) {
      if (row.length < 2) continue;
      final label = row[0].trim();
      final valueCell = row[1].trim();
      if (label.isEmpty || label.toUpperCase() == 'ITEM') continue;
      if (label.split('').every((c) => c == '-' || c == ' ')) continue;

      final valueMatch = _valueCellRe.firstMatch(valueCell);
      if (valueMatch == null) {
        skipped.add('$label: não deu para ler a quantidade "$valueCell"');
        continue;
      }

      final reportUnit =
          _reportUnits[valueMatch.namedGroup('unit')!.toLowerCase()]!;
      final nameNorm = normalize(label);
      final nutrientId = resolveId(nameNorm, reportUnit);
      if (nutrientId == null) {
        unknown.add(label);
        continue;
      }

      var amount = double.parse(
        valueMatch.namedGroup('value')!.replaceAll(',', '.'),
      );
      final catalogUnit = catalog[nutrientId]?.unit;
      if (catalogUnit == null) {
        skipped.add('$label: nutriente não encontrado no catálogo atual');
        continue;
      }
      if (reportUnit != catalogUnit) {
        final converted = convertAmount(amount, reportUnit, catalogUnit);
        if (converted.error != null) {
          skipped.add('$label: ${converted.error}');
          continue;
        }
        amount = converted.amount!;
      }

      if (seen.containsKey(nutrientId)) {
        skipped.add('$label: duplicado de "${seen[nutrientId]}"');
        continue;
      }
      seen[nutrientId] = label;
      rows.add(ParsedNutritionRow(
        nutrientId: nutrientId,
        amount: amount,
        label: label,
      ));
    }

    return ParsedProduct(
      baseAmount: baseAmount,
      baseUnit: baseUnit,
      rows: rows,
      unknownLabels: unknown,
      skippedNotes: skipped,
    );
  }

  /// The nutrition table is identified by shape, not by a preceding
  /// markdown heading (there is none in real DOM data): the table with the
  /// most rows whose second cell parses as a value+unit cell wins, as long
  /// as it clears a small threshold - a "Característica Geral" table can
  /// incidentally have one value-shaped row too (e.g. "Peso líquido: 500
  /// g"), but a real nutrition table has many. Threshold is a heuristic to
  /// tune once verified against a real product page.
  static List<List<String>>? _findNutritionTable(
    List<List<List<String>>> tables,
  ) {
    List<List<String>>? best;
    var bestCount = 0;
    for (final table in tables) {
      final count = table
          .where((row) =>
              row.length >= 2 && _valueCellRe.hasMatch(row[1].trim()))
          .length;
      if (count > bestCount) {
        bestCount = count;
        best = table;
      }
    }
    return bestCount >= 3 ? best : null;
  }

  /// Deterministic id so re-scanning the same product updates this user's
  /// own row instead of duplicating it (see the RLS note in the plan: an
  /// app-created food is always user-owned, so this only needs to stay
  /// stable across this app's own scans, not match a Python-generated id
  /// for the same product name).
  ///
  /// Implements uuid5 by hand rather than calling package:uuid's `v5()`
  /// because that method validates the namespace as strict RFC4122 before
  /// hashing, and [foodNamespace] (chosen to match FOOD_NAMESPACE in
  /// scripts/product_page_to_sql.py) has a version nibble ('d') the strict
  /// pattern rejects - Python's uuid module has no such restriction. This
  /// mirrors UuidV5.generate()'s algorithm exactly, just skipping that
  /// validation on the namespace parse.
  static String foodUuidFor(String name) {
    final namespaceBytes = Uuid.parse(foodNamespace, validate: false);
    final nameBytes = utf8.encode(normalize(name));
    final hash = crypto.sha1.convert([...namespaceBytes, ...nameBytes]).bytes;
    hash[6] = (hash[6] & 0x0f) | 0x50;
    hash[8] = (hash[8] & 0x3f) | 0x80;
    return Uuid.unparse(hash.sublist(0, 16));
  }
}
