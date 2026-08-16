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

FoodRecipe _recipe(
  List<(Food, double)> items, {
  double? yieldAmount,
}) {
  return FoodRecipe(
    id: 'r1',
    name: 'Panqueca',
    yieldAmount: yieldAmount,
    items: [
      for (var i = 0; i < items.length; i++)
        FoodRecipeItem(
          id: 'i$i',
          food: items[i].$1,
          amount: items[i].$2,
          sortOrder: i,
        ),
    ],
  );
}

void main() {
  // 364 kcal / 10 g protein per 100 g.
  final flour = _food('flour', nutrients: {
    NutrientId.calories: 364,
    NutrientId.protein: 10,
    NutrientId.iron: 1.2,
  });
  // Catalogued per 100 ml.
  final milk = _food('milk', baseUnit: 'ml', nutrients: {
    NutrientId.calories: 64,
    NutrientId.protein: 3.2,
  });

  // 200 g flour + 300 ml milk.
  List<(Food, double)> ingredients() => [(flour, 200), (milk, 300)];

  group('FoodRecipe', () {
    test('weighs the sum of its ingredients when there is no yield', () {
      final recipe = _recipe(ingredients());
      expect(recipe.ingredientsAmount, 500);
      expect(recipe.weight, 500);
      expect(recipe.hasYield, isFalse);
    });

    test('sums each ingredient scaled by its own base amount', () {
      final nutrients = _recipe(ingredients()).nutrients;
      expect(nutrients[NutrientId.calories]!.amount,
          closeTo(364 * 2 + 64 * 3, 1e-9));
      expect(nutrients[NutrientId.protein]!.amount,
          closeTo(20 + 9.6, 1e-9));
      // Only the flour lists iron.
      expect(nutrients[NutrientId.iron]!.amount, closeTo(2.4, 1e-9));
    });

    test('keeps the nutrient identity of the catalog', () {
      final iron = _recipe(ingredients()).nutrients[NutrientId.iron]!;
      expect(iron.id, NutrientId.iron);
      expect(iron.name, NutrientId.iron.name);
    });

    test('a yield concentrates the same nutrients into less weight', () {
      final recipe = _recipe(ingredients(), yieldAmount: 400);
      expect(recipe.hasYield, isTrue);
      expect(recipe.weight, 400);
      // Cooking loses water, never calories.
      expect(recipe.nutrients[NutrientId.calories]!.amount,
          closeTo(920, 1e-9));
      // ...so 100 g of the finished dish is denser than 100 g of the
      // raw mixture: 230 kcal instead of 184.
      expect(recipe.asFood().get(NutrientId.calories) * 100 / 400,
          closeTo(230, 1e-9));
    });

    test('a zero or missing yield falls back to the ingredients', () {
      expect(_recipe(ingredients(), yieldAmount: 0).weight, 500);
    });

    test('an empty recipe weighs nothing instead of dividing by it', () {
      final empty = _recipe([]);
      expect(empty.weight, 0);
      expect(empty.nutrients, isEmpty);
      expect(empty.asFood().baseAmount, 0);
    });

    test('ignores an ingredient catalogued with no base amount', () {
      final broken =
          _food('broken', baseAmount: 0, nutrients: {NutrientId.calories: 1});
      final recipe = _recipe([(flour, 100), (broken, 50)]);
      expect(recipe.nutrients[NutrientId.calories]!.amount,
          closeTo(364, 1e-9));
    });
  });

  group('FoodRecipe.asFood', () {
    test('behaves like any other food in the log', () {
      final entry = FoodEntry(
        id: 'e1',
        userId: 'u1',
        entryDate: '2026-08-16',
        food: _recipe(ingredients()).asFood(),
        amount: 250,
      );
      // Half the recipe.
      expect(entry.nutrient(NutrientId.calories), closeTo(460, 1e-9));
      expect(entry.nutrient(NutrientId.protein), closeTo(14.8, 1e-9));
      expect(entry.amountLabel, '250 g');
    });

    test('a recipe entry adds up alongside a plain food entry', () {
      final totals = calculateTotals([
        FoodEntry(
          id: 'e1',
          userId: 'u1',
          entryDate: '2026-08-16',
          food: _recipe(ingredients()).asFood(),
          amount: 100,
        ),
        FoodEntry(
          id: 'e2',
          userId: 'u1',
          entryDate: '2026-08-16',
          food: flour,
          amount: 50,
        ),
      ]);
      expect(totals[NutrientId.calories], closeTo(184 + 182, 1e-9));
    });

    test('an empty recipe contributes nothing rather than NaN', () {
      final entry = FoodEntry(
        id: 'e1',
        userId: 'u1',
        entryDate: '2026-08-16',
        food: _recipe([]).asFood(),
        amount: 100,
      );
      expect(entry.nutrient(NutrientId.calories), 0);
      expect(calculateTotals([entry]), isEmpty);
    });
  });

  group('FoodPackage', () {
    const pack = FoodPackage(
      id: 'p1',
      foodId: 'biscuit',
      name: 'Pacote pequeno',
      amount: 140,
    );
    const unnamed =
        FoodPackage(id: 'p2', foodId: 'biscuit', amount: 400);

    test('falls back to the weight when it has no name', () {
      expect(pack.labelFor('g'), 'Pacote pequeno');
      expect(unnamed.labelFor('g'), '400 g');
    });

    test('the log shows how many packs the weight came from', () {
      final biscuit = _food('biscuit', nutrients: {
        NutrientId.calories: 480,
      });
      final entry = FoodEntry(
        id: 'e1',
        userId: 'u1',
        entryDate: '2026-08-16',
        food: biscuit,
        package: pack,
        amount: 280,
      );
      expect(entry.amountLabel, '2 × Pacote pequeno · 280 g');
      // The package only labels the row; the nutrients still come from
      // the food, per 100 g.
      expect(entry.nutrient(NutrientId.calories), closeTo(1344, 1e-9));
    });

    test('half a pack reads as a fraction, not a rounded count', () {
      final biscuit =
          _food('biscuit', nutrients: {NutrientId.calories: 480});
      final entry = FoodEntry(
        id: 'e1',
        userId: 'u1',
        entryDate: '2026-08-16',
        food: biscuit,
        package: pack,
        amount: 70,
      );
      expect(entry.amountLabel, '0.5 × Pacote pequeno · 70.0 g');
    });
  });

  group('FoodRecipe.fromJson', () {
    final catalog = {
      NutrientId.calories:
          _n(NutrientId.calories, 0, unit: NutrientUnit.kcal),
      NutrientId.protein: _n(NutrientId.protein, 0),
    };

    Map<String, dynamic> itemJson(
        String id, String foodId, String amount, int sortOrder,
        {required String calories}) {
      return {
        'id': id,
        'amount': amount,
        'sort_order': sortOrder,
        'food': {
          'id': foodId,
          'name': foodId,
          'base_amount': '100.000',
          'base_unit': 'g',
          'food_nutrients': [
            {'nutrient_id': 'calories', 'amount': calories},
          ],
        },
      };
    }

    test('reads the embedded ingredients and their foods', () {
      final recipe = FoodRecipe.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'name': 'Panqueca',
        'yield_amount': '400.000',
        'items': [
          itemJson('i1', 'flour', '200.000', 0, calories: '364'),
          itemJson('i2', 'milk', '300.000', 1, calories: '64'),
        ],
      }, catalog);

      expect(recipe.items.length, 2);
      expect(recipe.yieldAmount, 400);
      expect(recipe.weight, 400);
      expect(recipe.nutrients[NutrientId.calories]!.amount,
          closeTo(920, 1e-9));
    });

    test('orders ingredients by sort_order, not by how they arrived', () {
      final recipe = FoodRecipe.fromJson({
        'id': 'r1',
        'name': 'Panqueca',
        'items': [
          itemJson('i2', 'milk', '300.000', 1, calories: '64'),
          itemJson('i1', 'flour', '200.000', 0, calories: '364'),
        ],
      }, catalog);

      expect(recipe.items.map((i) => i.food.name).toList(),
          ['flour', 'milk']);
    });

    test('a null yield means the sum of the ingredients', () {
      final recipe = FoodRecipe.fromJson({
        'id': 'r1',
        'name': 'Panqueca',
        'yield_amount': null,
        'items': [
          itemJson('i1', 'flour', '200.000', 0, calories: '364'),
        ],
      }, catalog);

      expect(recipe.yieldAmount, isNull);
      expect(recipe.weight, 200);
    });
  });

  group('FoodEntry.fromJson', () {
    final catalog = {
      NutrientId.calories:
          _n(NutrientId.calories, 0, unit: NutrientUnit.kcal),
    };

    test('a recipe row is flattened into the food it stands for', () {
      final entry = FoodEntry.fromJson({
        'id': 'e1',
        'user_id': 'u1',
        'entry_date': '2026-08-16',
        'amount': '250',
        'food': null,
        'package': null,
        'recipe': {
          'id': 'r1',
          'name': 'Panqueca',
          'items': [
            {
              'id': 'i1',
              'amount': '500.000',
              'sort_order': 0,
              'food': {
                'id': 'flour',
                'name': 'Farinha',
                'base_amount': '100.000',
                'base_unit': 'g',
                'food_nutrients': [
                  {'nutrient_id': 'calories', 'amount': '364'},
                ],
              },
            },
          ],
        },
      }, catalog);

      expect(entry.recipe, isNotNull);
      expect(entry.food.label, 'Panqueca');
      expect(entry.food.baseAmount, 500);
      expect(entry.nutrient(NutrientId.calories), closeTo(910, 1e-9));
    });

    test('an ingredient row is unchanged by the new columns', () {
      final entry = FoodEntry.fromJson({
        'id': 'e2',
        'user_id': 'u1',
        'entry_date': '2026-08-16',
        'amount': '150',
        'recipe': null,
        'package': null,
        'food': {
          'id': 'flour',
          'name': 'Farinha',
          'base_amount': '100.000',
          'base_unit': 'g',
          'food_nutrients': [
            {'nutrient_id': 'calories', 'amount': '364'},
          ],
        },
      }, catalog);

      expect(entry.recipe, isNull);
      expect(entry.package, isNull);
      expect(entry.nutrient(NutrientId.calories), closeTo(546, 1e-9));
    });

    test('a package row keeps its weight and its label', () {
      final entry = FoodEntry.fromJson({
        'id': 'e3',
        'user_id': 'u1',
        'entry_date': '2026-08-16',
        'amount': '280',
        'recipe': null,
        'package': {
          'id': 'p1',
          'user_id': 'u1',
          'food_id': 'biscuit',
          'name': 'Pacote pequeno',
          'amount': '140.000',
        },
        'food': {
          'id': 'biscuit',
          'name': 'Bolacha',
          'base_amount': '100.000',
          'base_unit': 'g',
          'food_nutrients': [
            {'nutrient_id': 'calories', 'amount': '480'},
          ],
        },
      }, catalog);

      expect(entry.package?.name, 'Pacote pequeno');
      expect(entry.amount, 280);
      expect(entry.amountLabel, '2 × Pacote pequeno · 280 g');
    });
  });

  group('formatQuantity', () {
    test('keeps whole numbers whole', () {
      expect(formatQuantity(2), '2');
      expect(formatQuantity(140), '140');
    });

    test('does not round away what formatNutrientAmount would', () {
      expect(formatQuantity(1250.5), '1250.5');
      expect(formatNutrientAmount(1250.5), '1251');
    });

    test('trims to the precision the column stores', () {
      expect(formatQuantity(350.25), '350.25');
      expect(formatQuantity(1 / 3), '0.333');
    });
  });
}
