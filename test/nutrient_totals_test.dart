import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/food.dart';
import 'package:recettas/models/nutrient.dart';

Nutrient _n(NutrientId id, double amount,
    {NutrientUnit unit = NutrientUnit.g}) {
  return Nutrient(
    id: id,
    name: id.name,
    category: NutrientCategory.macronutrient,
    unit: unit,
    amount: amount,
  );
}

Food _food(
  String id, {
  double baseAmount = 100,
  String baseUnit = 'g',
  required Map<NutrientId, double> nutrients,
}) {
  return Food(
    id: id,
    name: id,
    baseAmount: baseAmount,
    baseUnit: baseUnit,
    nutrients: {
      for (final entry in nutrients.entries)
        entry.key: _n(entry.key, entry.value),
    },
  );
}

FoodEntry _entry(Food food, double amount) {
  return FoodEntry(
    id: '${food.id}-$amount',
    userId: 'u1',
    entryDate: '2026-07-29',
    food: food,
    amount: amount,
  );
}

void main() {
  final chicken = _food('chicken', nutrients: {
    NutrientId.calories: 165,
    NutrientId.protein: 31,
    NutrientId.fat: 3.6,
  });

  // Catalogued per 100 ml rather than per 100 g.
  final milk = _food('milk', baseUnit: 'ml', nutrients: {
    NutrientId.calories: 64,
    NutrientId.protein: 3.2,
  });

  // A serving-sized food: values are per one 30 g unit, not per 100 g.
  final bar = _food('bar', baseAmount: 30, nutrients: {
    NutrientId.calories: 120,
    NutrientId.protein: 10,
  });

  group('FoodEntry.nutrient', () {
    test('scales by amount over the food base amount', () {
      expect(_entry(chicken, 200).nutrient(NutrientId.protein),
          closeTo(62, 1e-9));
      expect(_entry(chicken, 50).nutrient(NutrientId.calories),
          closeTo(82.5, 1e-9));
    });

    test('uses base_amount, not a hardcoded 100', () {
      expect(_entry(bar, 60).nutrient(NutrientId.calories),
          closeTo(240, 1e-9));
    });

    test('treats ml exactly like g - no density conversion', () {
      expect(_entry(milk, 200).nutrient(NutrientId.calories),
          closeTo(128, 1e-9));
    });

    test('returns zero for a nutrient the food does not list', () {
      expect(_entry(chicken, 100).nutrient(NutrientId.vitaminB12), 0);
    });
  });

  group('calculateTotals', () {
    test('sums across foods with different base units and amounts', () {
      final totals = calculateTotals([
        _entry(chicken, 200),
        _entry(milk, 250),
        _entry(bar, 30),
      ]);

      expect(totals[NutrientId.calories],
          closeTo(330 + 160 + 120, 1e-9));
      expect(totals[NutrientId.protein], closeTo(62 + 8 + 10, 1e-9));
      // Only chicken lists fat.
      expect(totals[NutrientId.fat], closeTo(7.2, 1e-9));
    });

    test('adds up repeated entries of the same food', () {
      final totals =
          calculateTotals([_entry(chicken, 100), _entry(chicken, 50)]);
      expect(totals[NutrientId.protein], closeTo(46.5, 1e-9));
    });

    test('is empty for no entries', () {
      expect(calculateTotals([]), isEmpty);
    });

    test('skips foods with a non-positive base amount', () {
      final broken = _food('broken',
          baseAmount: 0, nutrients: {NutrientId.calories: 100});
      expect(calculateTotals([_entry(broken, 100)]), isEmpty);
    });
  });

  group('nutrient id round-trip', () {
    test('every enum value maps back from its name', () {
      for (final id in NutrientId.values) {
        expect(nutrientIdFromName(id.name), id);
      }
    });

    test('unknown ids resolve to null instead of a wrong nutrient', () {
      expect(nutrientIdFromName('vitaminB21'), isNull);
      // Comparison is case sensitive, like the database column.
      expect(nutrientIdFromName('vitaminb12'), isNull);
      expect(nutrientIdFromName(null), isNull);
    });
  });

  group('Food.fromJson', () {
    final catalog = {
      NutrientId.calories: _n(NutrientId.calories, 0,
          unit: NutrientUnit.kcal),
      NutrientId.protein: _n(NutrientId.protein, 0),
    };

    test('reads embedded food_nutrients rows', () {
      final food = Food.fromJson({
        'id': 'f1',
        'user_id': null,
        'name': 'Arroz',
        'base_amount': '100.000',
        'base_unit': 'g',
        'food_nutrients': [
          {'nutrient_id': 'calories', 'amount': '130'},
          {'nutrient_id': 'protein', 'amount': '2.7'},
        ],
      }, catalog);

      expect(food.get(NutrientId.calories), 130);
      expect(food.get(NutrientId.protein), closeTo(2.7, 1e-9));
      expect(food.nutrients[NutrientId.calories]!.unit,
          NutrientUnit.kcal);
    });

    test('drops rows naming a nutrient the app does not know', () {
      final food = Food.fromJson({
        'id': 'f2',
        'name': 'Teste',
        'base_amount': 100,
        'base_unit': 'g',
        'food_nutrients': [
          {'nutrient_id': 'calories', 'amount': 10},
          {'nutrient_id': 'vitaminB21', 'amount': 999},
        ],
      }, catalog);

      expect(food.nutrients.length, 1);
      expect(food.get(NutrientId.calories), 10);
    });
  });
}
