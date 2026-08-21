import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/nutrient.dart';
import 'package:recettas/services/product_page_extractor.dart';
import 'package:recettas/services/product_page_parser.dart';

Nutrient _catalogEntry(NutrientId id, NutrientUnit unit) => Nutrient(
      id: id,
      name: id.name,
      category: NutrientCategory.macronutrient,
      unit: unit,
    );

final _catalog = <NutrientId, Nutrient>{
  NutrientId.calories: _catalogEntry(NutrientId.calories, NutrientUnit.kcal),
  NutrientId.carbohydrates:
      _catalogEntry(NutrientId.carbohydrates, NutrientUnit.g),
  NutrientId.protein: _catalogEntry(NutrientId.protein, NutrientUnit.g),
  NutrientId.fat: _catalogEntry(NutrientId.fat, NutrientUnit.g),
  NutrientId.saturatedFat:
      _catalogEntry(NutrientId.saturatedFat, NutrientUnit.g),
  NutrientId.transFat: _catalogEntry(NutrientId.transFat, NutrientUnit.g),
  NutrientId.fiber: _catalogEntry(NutrientId.fiber, NutrientUnit.g),
  NutrientId.sodium: _catalogEntry(NutrientId.sodium, NutrientUnit.mg),
  NutrientId.sugar: _catalogEntry(NutrientId.sugar, NutrientUnit.g),
  NutrientId.addedSugar: _catalogEntry(NutrientId.addedSugar, NutrientUnit.g),
};

/// Mirrors the known values in
/// migrations/nutrition/salsicha_hot_dog_sadia_500g_10_unidades.sql, as an
/// ExtractedPage would come back from a real webview scan.
final _salsichaPage = ExtractedPage(
  title: 'Salsicha Hot-Dog Sadia 500g 10 Unidades',
  bodyText: 'Cód.: 1171433\n'
      'Descrição do produto...\n'
      'Tabela nutricional\n'
      'Porção de 50 g\n'
      '% VD referente a uma dieta de 2000 kcal.',
  tables: [
    // Característica Geral - has one incidental value-shaped row ("500
    // g"), must NOT be picked as the nutrition table.
    [
      ['Marca', 'Sadia'],
      ['Peso líquido', '500 g'],
    ],
    [
      ['Valor energético', '207 kcal'],
      ['Carboidratos', '2,8 g'],
      ['Proteínas', '13 g'],
      ['Gorduras Totais', '16 g'],
      ['Gorduras Saturadas', '5,9 g'],
      ['Gorduras Trans', '0 g'],
      ['Fibra Alimentar', '0 g'],
      ['Sódio', '976 mg'],
      ['Açúcares Totais', '0 g'],
      ['Açúcares Adicionados', '0 g'],
    ],
  ],
);

void main() {
  group('ProductPageParser', () {
    test('finds brand from any table, not just the nutrition one', () {
      expect(ProductPageParser.findBrand(_salsichaPage.tables), 'Sadia');
    });

    test('finds the product code, display-only', () {
      expect(ProductPageParser.findCode(_salsichaPage.bodyText), '1171433');
    });

    test('picks the nutrition table over an incidental value-shaped row',
        () {
      final parsed =
          ProductPageParser.parseNutritionTable(_salsichaPage, _catalog);
      expect(parsed, isNotNull);
      expect(parsed!.baseAmount, 50);
      expect(parsed.baseUnit, 'g');
      expect(parsed.rows, hasLength(10));
      expect(parsed.unknownLabels, isEmpty);
      expect(parsed.skippedNotes, isEmpty);

      final byId = {for (final r in parsed.rows) r.nutrientId: r.amount};
      expect(byId[NutrientId.calories], 207);
      expect(byId[NutrientId.carbohydrates], 2.8);
      expect(byId[NutrientId.protein], 13);
      expect(byId[NutrientId.fat], 16);
      expect(byId[NutrientId.saturatedFat], 5.9);
      expect(byId[NutrientId.sodium], 976);
    });

    test('returns null when there is no nutrition section', () {
      final page = ExtractedPage(
        title: 'Alguma outra página',
        bodyText: 'Nada de tabela nutricional aqui.',
        tables: const [],
      );
      expect(ProductPageParser.parseNutritionTable(page, _catalog), isNull);
    });

    test('an unmapped label is reported, not guessed', () {
      final page = ExtractedPage(
        title: 'Produto teste',
        bodyText: 'Tabela nutricional\nPorção de 100 g',
        tables: [
          [
            ['Valor energético', '100 kcal'],
            ['Proteínas', '5 g'],
            ['Nutriente Inventado', '1 g'],
            ['Sódio', '10 mg'],
          ],
        ],
      );
      final parsed = ProductPageParser.parseNutritionTable(page, _catalog);
      expect(parsed, isNotNull);
      expect(parsed!.unknownLabels, ['Nutriente Inventado']);
      expect(parsed.rows.map((r) => r.nutrientId),
          containsAll([NutrientId.calories, NutrientId.protein, NutrientId.sodium]));
    });

    test('normalize strips accents and trailing punctuation', () {
      expect(ProductPageParser.normalize('Sódio:'), 'sodio');
      expect(ProductPageParser.normalize('  Ácido Fólico  '), 'acido folico');
    });

    test('foodUuidFor is stable across case/accent differences', () {
      final id1 =
          ProductPageParser.foodUuidFor('Salsicha Hot-Dog Sadia 500g');
      final id2 =
          ProductPageParser.foodUuidFor('salsicha hot-dog sadia 500g');
      expect(id1, id2);
    });

    test('convertAmount handles mass units and refuses the rest', () {
      final gToMg = ProductPageParser.convertAmount(
          1, NutrientUnit.g, NutrientUnit.mg);
      expect(gToMg.amount, 1000);
      expect(gToMg.error, isNull);

      final refused = ProductPageParser.convertAmount(
          1, NutrientUnit.g, NutrientUnit.kcal);
      expect(refused.amount, isNull);
      expect(refused.error, isNotNull);
    });
  });
}
