import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/nutrient.dart';

/// The nutrient catalog is deliberately duplicated: Postgres needs the
/// rows so hand-written food_nutrients inserts get foreign-key validated,
/// and Dart needs the enum for compile-time constants. That duplication
/// can drift, so these tests parse the migration and hold the two sides
/// to each other.
/// One seeded row of public.nutrients.
typedef _CatalogRow = ({
  String id,
  String name,
  String category,
  String unit,
  int sortOrder,
});

void main() {
  // ('id', 'Nome', 'category', 'unit', 123, false) - specific enough that
  // no other table's insert in migrations/ matches it.
  final rowPattern = RegExp(
    r"^\s*\('([A-Za-z0-9]+)',\s*'(.+?)',\s*'([A-Za-z]+)',\s*"
    r"'([a-z]+)',\s*(\d+),\s*(true|false)\)",
    multiLine: true,
  );

  // Replay every migration in numeric order and let later ones win, the
  // way the SQL editor applies them - so this is the catalog the database
  // actually ends up with, not just the newest file's view of it.
  final files = Directory('migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final catalog = <String, _CatalogRow>{};
  for (final file in files) {
    for (final m in rowPattern.allMatches(file.readAsStringSync())) {
      catalog[m.group(1)!] = (
        id: m.group(1)!,
        name: m.group(2)!,
        category: m.group(3)!,
        unit: m.group(4)!,
        sortOrder: int.parse(m.group(5)!),
      );
    }
  }
  final rows = catalog.values.toList();

  test('the migrations seed a catalog at all', () {
    expect(rows, isNotEmpty, reason: 'row pattern matched nothing');
  });

  test('seeded ids and NutrientId agree in both directions', () {
    final seeded = catalog.keys.toSet();
    final declared = NutrientId.values.map((n) => n.name).toSet();

    expect(seeded.difference(declared), isEmpty,
        reason: 'seeded in SQL but missing from the NutrientId enum');
    expect(declared.difference(seeded), isEmpty,
        reason: 'declared in Dart but never seeded into public.nutrients');
  });

  test('every seeded category and unit parses back to an enum value', () {
    final categories =
        NutrientCategory.values.map((c) => c.name).toSet();
    final units = NutrientUnit.values.map((u) => u.name).toSet();

    for (final row in rows) {
      expect(categories, contains(row.category),
          reason: '${row.id} has an unknown category');
      expect(units, contains(row.unit),
          reason: '${row.id} has an unknown unit');
    }
  });

  test('sort_order is unique so the chart row order is stable', () {
    final bySortOrder = <int, List<String>>{};
    for (final row in rows) {
      bySortOrder.putIfAbsent(row.sortOrder, () => []).add(row.id);
    }
    final clashes = bySortOrder.entries.where((e) => e.value.length > 1);
    expect(clashes, isEmpty,
        reason: 'nutrients share a sort_order: '
            '${clashes.map((e) => '${e.key} -> ${e.value}').join(', ')}');
  });

  test('every category has at least one nutrient', () {
    final seededCategories = rows.map((r) => r.category).toSet();
    for (final category in NutrientCategory.values) {
      expect(seededCategories, contains(category.name),
          reason: '${category.name} would render an empty section');
    }
  });

  test('the units the recommendation check accepts cover the catalog', () {
    // migrations/016 constrains nutrient_recommendations.unit to nine
    // values; a catalog unit outside that list could never get a target.
    final targets =
        File('migrations/016_create_nutrient_recommendations.sql')
            .readAsStringSync();
    for (final row in rows) {
      expect(targets, contains("'${row.unit}'"),
          reason: '${row.id} uses a unit no target can use');
    }
  });

  test('the category check constraint allows every NutrientCategory', () {
    // The constraint is rewritten in 020; a category added in Dart but
    // not there would be rejected on insert.
    final sql =
        File('migrations/020_extend_nutrients.sql').readAsStringSync();
    final constraint = sql.substring(sql.indexOf('add constraint'));
    for (final category in NutrientCategory.values) {
      expect(constraint, contains("'${category.name}'"),
          reason: '${category.name} is not in nutrients_category_check');
    }
  });

  group('formatNutrientAmount', () {
    test('keeps three decimals for trace amounts', () {
      expect(formatNutrientAmount(0.031), '0.031');
      expect(formatNutrientAmount(0.009), '0.009');
    });

    test('shortens as values grow', () {
      expect(formatNutrientAmount(0.25), '0.25');
      expect(formatNutrientAmount(3.6), '3.6');
      expect(formatNutrientAmount(24.9), '24.9');
      expect(formatNutrientAmount(403), '403');
      expect(formatNutrientAmount(0), '0');
    });
  });
}
