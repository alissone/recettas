import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/food.dart';
import 'package:recettas/models/nutrient.dart';
import 'package:recettas/models/recipe.dart';
import 'package:recettas/recipe_view.dart';

Food _food(String name, {double calories = 0, String baseUnit = 'g'}) {
  return Food(
    id: name,
    name: name,
    baseUnit: baseUnit,
    nutrients: {
      NutrientId.calories: Nutrient(
        id: NutrientId.calories,
        name: 'Calorias',
        category: NutrientCategory.macronutrient,
        unit: NutrientUnit.kcal,
        amount: calories,
      ),
    },
  );
}

Recipe _recipe({
  List<RecipeIngredient> ingredients = const [],
  List<RecipeSection> sections = const [],
  double? yieldAmount,
}) {
  return Recipe(
    id: 'r1',
    userId: 'u1',
    name: 'Panqueca',
    prepTime: '10 min',
    totalTime: '25 min',
    yieldAmount: yieldAmount,
    ingredients: ingredients,
    sections: sections,
  );
}

final _flour = RecipeIngredient(
  id: 'i1',
  food: _food('Farinha de trigo', calories: 364),
  amount: 200,
);
final _milk = RecipeIngredient(
  id: 'i2',
  food: _food('Leite', calories: 64, baseUnit: 'ml'),
  amount: 300,
  sortOrder: 1,
);

Future<void> _pump(WidgetTester tester, Recipe recipe,
    {Future<Recipe?> Function(Recipe)? onEdit}) {
  return tester.pumpWidget(
      MaterialApp(home: RecipeView(recipe: recipe, onEdit: onEdit)));
}

/// Whether the [index]th panel is open. AnimatedCrossFade keeps both
/// children in the tree, so finding the text says nothing about whether
/// it is on screen - the fade state is what does. Panels are in the
/// order the view builds them: ingredients first, then the sections.
bool _isOpen(WidgetTester tester, int index) {
  final panels =
      tester.widgetList<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
  return panels.elementAt(index).crossFadeState ==
      CrossFadeState.showSecond;
}

void main() {
  group('RecipeView', () {
    testWidgets('shows the name and both times', (tester) async {
      await _pump(tester, _recipe(ingredients: [_flour, _milk]));

      expect(find.text('Panqueca'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
    });

    testWidgets('scores the finished dish once it has ingredients',
        (tester) async {
      await _pump(tester, _recipe(ingredients: [_flour, _milk]));

      // 200 g + 300 ml, no yield.
      expect(find.text('500 g'), findsOneWidget);
      // 364*2 + 64*3.
      expect(find.text('920 kcal'), findsOneWidget);
      expect(find.text('184 kcal'), findsOneWidget);
    });

    testWidgets('a yield makes the same nutrients denser', (tester) async {
      await _pump(tester,
          _recipe(ingredients: [_flour, _milk], yieldAmount: 400));

      expect(find.text('400 g'), findsOneWidget);
      expect(find.text('920 kcal'), findsOneWidget);
      expect(find.text('230 kcal'), findsOneWidget);
    });

    testWidgets('the ingredient list expands into shopping lines',
        (tester) async {
      await _pump(tester, _recipe(ingredients: [_flour, _milk]));

      // Collapsed to start with.
      expect(find.text('Ingredientes'), findsOneWidget);
      expect(_isOpen(tester, 0), isFalse);

      await tester.tap(find.text('Ingredientes'));
      await tester.pumpAndSettle();

      expect(_isOpen(tester, 0), isTrue);
      expect(find.text('200 g de Farinha de trigo'), findsOneWidget);
      expect(find.text('300 ml de Leite'), findsOneWidget);
      expect(find.text('728 kcal'), findsOneWidget);
    });

    testWidgets('free-form sections keep their own titles', (tester) async {
      await _pump(
        tester,
        _recipe(ingredients: [
          _flour
        ], sections: const [
          RecipeSection(
              title: 'Modo de preparo', items: ['Misture', 'Frite']),
          RecipeSection(title: 'Dicas do vovô', items: ['Sirva quente']),
        ]),
      );

      expect(find.text('Modo de preparo'), findsOneWidget);
      expect(find.text('Dicas do vovô'), findsOneWidget);

      await tester.tap(find.text('Dicas do vovô'));
      await tester.pumpAndSettle();

      expect(find.text('Sirva quente'), findsOneWidget);
      // Opening one panel leaves the others closed: ingredients (0),
      // "Modo de preparo" (1), "Dicas do vovô" (2).
      expect(_isOpen(tester, 2), isTrue);
      expect(_isOpen(tester, 0), isFalse);
      expect(_isOpen(tester, 1), isFalse);
    });

    testWidgets('a recipe with no ingredients shows no nutrition',
        (tester) async {
      await _pump(
        tester,
        _recipe(sections: const [
          RecipeSection(title: 'Modo de preparo', items: ['Misture tudo']),
        ]),
      );

      expect(find.text('Modo de preparo'), findsOneWidget);
      expect(find.text('Ingredientes'), findsNothing);
      expect(find.text('Receita inteira'), findsNothing);
    });

    testWidgets('shared recipes have no edit button', (tester) async {
      await _pump(tester, _recipe(ingredients: [_flour]));

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('editing swaps in whatever the editor returned',
        (tester) async {
      final edited = Recipe(
        id: 'r1',
        userId: 'u1',
        name: 'Panqueca integral',
        ingredients: [_flour],
      );
      await _pump(
        tester,
        _recipe(ingredients: [_flour]),
        onEdit: (_) async => edited,
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Panqueca integral'), findsOneWidget);
      expect(find.text('Panqueca'), findsNothing);
    });

    testWidgets('a cancelled edit leaves the recipe alone', (tester) async {
      await _pump(
        tester,
        _recipe(ingredients: [_flour]),
        onEdit: (_) async => null,
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Panqueca'), findsOneWidget);
    });
  });
}
