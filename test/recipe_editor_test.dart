import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/food.dart';
import 'package:recettas/models/nutrient.dart';
import 'package:recettas/screens/recipe_editor_screen.dart';

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

final _foods = [
  _food('Farinha de trigo', calories: 364),
  _food('Leite', calories: 64, baseUnit: 'ml'),
];

/// The editor is one long ListView, and a SliverList only lays out what
/// fits. A tall surface keeps every card in the tree so the tests can
/// reach the section controls without scrolling first.
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester
      .pumpWidget(MaterialApp(home: RecipeEditorScreen(foods: _foods)));
}

/// Picks [name] out of the catalog and gives it [amount], the way a user
/// does: the picker sheet, then the amount dialog.
Future<void> _addIngredient(
    WidgetTester tester, String name, String amount) async {
  await tester.tap(find.text('Adicionar ingrediente'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, amount);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  group('RecipeEditorScreen ingredients', () {
    testWidgets('adding one survives the dialog closing', (tester) async {
      await _pump(tester);
      await _addIngredient(tester, 'Farinha de trigo', '200');

      // The crash this guards against fired while the dialog animated
      // out, so it is pumpAndSettle above that would surface it.
      expect(tester.takeException(), isNull);
      expect(find.text('200 g · 728 kcal'), findsOneWidget);
    });

    testWidgets('the totals add up across ingredients', (tester) async {
      await _pump(tester);
      await _addIngredient(tester, 'Farinha de trigo', '200');
      await _addIngredient(tester, 'Leite', '300');

      // 200 g + 300 ml, no yield typed.
      expect(find.text('500 g'), findsWidgets);
      expect(find.text('920 kcal'), findsOneWidget);
      expect(find.text('184 kcal'), findsOneWidget);
    });

    testWidgets('a yield divides the same nutrients by less weight',
        (tester) async {
      await _pump(tester);
      await _addIngredient(tester, 'Farinha de trigo', '200');
      await _addIngredient(tester, 'Leite', '300');

      await tester.enterText(
          find.widgetWithText(TextField, 'Rendimento (opcional)'), '400');
      await tester.pumpAndSettle();

      expect(find.text('400 g'), findsOneWidget);
      expect(find.text('920 kcal'), findsOneWidget);
      expect(find.text('230 kcal'), findsOneWidget);
    });

    testWidgets('a bad amount keeps the dialog open to be fixed',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Adicionar ingrediente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Farinha de trigo'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '0');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Informe uma quantidade válida.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '150');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('150 g · 546 kcal'), findsOneWidget);
    });

    testWidgets('an ingredient already in the recipe is not offered twice',
        (tester) async {
      await _pump(tester);
      await _addIngredient(tester, 'Farinha de trigo', '200');

      await tester.tap(find.text('Adicionar ingrediente'));
      await tester.pumpAndSettle();

      expect(find.text('Já está na lista'), findsOneWidget);
    });

    testWidgets('removing one takes its weight back out', (tester) async {
      await _pump(tester);
      await _addIngredient(tester, 'Farinha de trigo', '200');
      await _addIngredient(tester, 'Leite', '300');

      await tester.tap(find.widgetWithIcon(IconButton, Icons.close).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('200 g · 728 kcal'), findsNothing);
      expect(find.text('300 ml · 192 kcal'), findsOneWidget);
    });
  });

  group('RecipeEditorScreen sections', () {
    testWidgets('a section can be added, filled and removed',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Adicionar seção'));
      await tester.pumpAndSettle();

      final title =
          find.widgetWithText(TextField, 'Título da seção');
      expect(title, findsOneWidget);
      await tester.enterText(title, 'Modo de preparo');
      await tester.enterText(
          find.widgetWithText(TextField, 'Passo 1'), 'Misture tudo');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Adicionar linha'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Passo 2'), findsOneWidget);

      await tester
          .tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(TextField, 'Título da seção'),
          findsNothing);
    });

    testWidgets('sections move up and down', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Adicionar seção'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Título da seção'), 'Primeira');
      await tester.tap(find.text('Adicionar seção'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Título da seção').last,
          'Segunda');
      await tester.pumpAndSettle();

      // The second card's "up" arrow: the first one's is disabled.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward)
          .last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final titles = tester
          .widgetList<TextField>(
              find.widgetWithText(TextField, 'Título da seção'))
          .map((f) => f.controller?.text)
          .toList();
      expect(titles, ['Segunda', 'Primeira']);
    });
  });
}
