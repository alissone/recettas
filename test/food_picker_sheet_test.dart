import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/food.dart';
import 'package:recettas/models/nutrient.dart';
import 'package:recettas/widgets/food_picker_sheet.dart';

Food _food(String id, String name, {String? brand, double calories = 0}) {
  return Food(
    id: id,
    name: name,
    brand: brand,
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

/// Pumps a button that opens the picker and records what it returns.
Future<void> _openPicker(
  WidgetTester tester,
  List<Food> foods, {
  Set<String> disabledIds = const {},
  required void Function(Food?) onPicked,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            onPicked(await showFoodPicker(context, foods,
                disabledIds: disabledIds));
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  final foods = [
    _food('f1', 'Arroz branco', brand: 'Tio João', calories: 130),
    _food('f2', 'Farinha de trigo', calories: 364),
    _food('f3', 'Leite integral', calories: 64),
  ];

  group('showFoodPicker', () {
    testWidgets('lists the catalog with its calories', (tester) async {
      await _openPicker(tester, foods, onPicked: (_) {});

      expect(find.text('Arroz branco · Tio João'), findsOneWidget);
      expect(find.text('Farinha de trigo'), findsOneWidget);
      expect(find.text('364 kcal por 100 g'), findsOneWidget);
    });

    testWidgets('filters as the search text is typed', (tester) async {
      await _openPicker(tester, foods, onPicked: (_) {});

      await tester.enterText(find.byType(TextField), 'leite');
      await tester.pumpAndSettle();

      expect(find.text('Leite integral'), findsOneWidget);
      expect(find.text('Farinha de trigo'), findsNothing);
    });

    testWidgets('search matches the brand too', (tester) async {
      await _openPicker(tester, foods, onPicked: (_) {});

      await tester.enterText(find.byType(TextField), 'tio joão');
      await tester.pumpAndSettle();

      expect(find.text('Arroz branco · Tio João'), findsOneWidget);
      expect(find.text('Leite integral'), findsNothing);
    });

    testWidgets('returns the tapped food', (tester) async {
      Food? picked;
      await _openPicker(tester, foods, onPicked: (f) => picked = f);

      await tester.tap(find.text('Leite integral'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'f3');
    });

    testWidgets('an ingredient already in the recipe cannot be picked',
        (tester) async {
      Food? picked;
      await _openPicker(tester, foods,
          disabledIds: {'f2'}, onPicked: (f) => picked = f);

      expect(find.text('Já está na lista'), findsOneWidget);

      await tester.tap(find.text('Farinha de trigo'));
      await tester.pumpAndSettle();

      // Still open, nothing chosen.
      expect(picked, isNull);
      expect(find.text('Leite integral'), findsOneWidget);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await _openPicker(tester, foods, onPicked: (_) {});

      await tester.enterText(find.byType(TextField), 'quiabo');
      await tester.pumpAndSettle();

      expect(find.text('Nenhum alimento encontrado.'), findsOneWidget);
    });
  });
}
