import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/nutrient.dart';

/// The nutrient catalog is deliberately duplicated: Postgres needs the
/// rows so hand-written food_nutrients inserts get foreign-key validated,
/// and Dart needs the enum for compile-time constants. That duplication
/// can drift, so these tests parse the migration and hold the two sides
/// to each other.
void main() {
  final migration =
      File('migrations/020_extend_nutrients.sql').readAsStringSync();

  // ('id', 'Nome', 'category', 'unit', 123, false)
  final rowPattern = RegExp(
    r"^\s*\('([A-Za-z0-9]+)',\s*'(.+?)',\s*'([A-Za-z]+)',\s*"
    r"'([a-z]+)',\s*(\d+),\s*(true|false)\)",
    multiLine: true,
  );

  final rows = rowPattern.allMatches(migration).toList();

  test('the migration seeds every nutrient exactly once', () {
    expect(rows, isNotEmpty, reason: 'row pattern matched nothing');

    final ids = rows.map((m) => m.group(1)!).toList();
    expect(ids.toSet().length, ids.length,
        reason: 'duplicate id in the seed');
  });

  test('seeded ids and NutrientId agree in both directions', () {
    final seeded = rows.map((m) => m.group(1)!).toSet();
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
      final id = row.group(1)!;
      expect(categories, contains(row.group(3)),
          reason: '$id has an unknown category');
      expect(units, contains(row.group(4)),
          reason: '$id has an unknown unit');
    }
  });

  test('sort_order is unique so the chart row order is stable', () {
    final orders = rows.map((m) => int.parse(m.group(5)!)).toList();
    expect(orders.toSet().length, orders.length,
        reason: 'two nutrients share a sort_order');
  });

  test('every category has at least one nutrient', () {
    final seededCategories = rows.map((m) => m.group(3)!).toSet();
    for (final category in NutrientCategory.values) {
      expect(seededCategories, contains(category.name),
          reason: '${category.name} would render an empty section');
    }
  });

  test('the units the recommendation check accepts cover the catalog', () {
    // migrations/016 constrains nutrient_recommendations.unit to the same
    // nine values; a catalog unit outside that list could never be given
    // a target.
    final targets =
        File('migrations/016_create_nutrient_recommendations.sql')
            .readAsStringSync();
    for (final row in rows) {
      expect(targets, contains("'${row.group(4)}'"),
          reason: '${row.group(1)} uses a unit no target can use');
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
