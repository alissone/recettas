import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/services/purchase_categorizer.dart';

void main() {
  test('golden: every real-data item keeps its reviewed category', () {
    // Fixture of every (item, store) pair from the real gastos.csv.
    // "category" is what categorizar.py produced and is kept only for
    // provenance — the app taxonomy has diverged from it. "app" is the
    // hand-reviewed expectation this test enforces; null means no rule
    // matched, so the purchase stays "sem categoria" for manual review.
    final cases = jsonDecode(
            File('test/fixtures/categorizer_cases.json')
                .readAsStringSync())
        as List<dynamic>;
    expect(cases, isNotEmpty);

    final mismatches = <String>[];
    for (final c in cases) {
      final item = c['item'] as String;
      final store = c['store'] as String?;
      final expected = c['app'] as String?;
      final actual = PurchaseCategorizer.categorize(item, store);
      if (actual != expected) {
        mismatches.add('"$item" (store: "$store"): '
            'expected $expected, got $actual');
      }
    }
    expect(mismatches, isEmpty,
        reason: 'Categorizer changed:\n${mismatches.join('\n')}');
  });

  test('quantity prefix is stripped before matching', () {
    expect(PurchaseCategorizer.categorize('2 Pizzas', null),
        PurchaseCategorizer.junk);
  });

  test('accent-stripped second pass', () {
    // No accented rule for "pao frances", matches on the stripped pass.
    expect(PurchaseCategorizer.categorize('Pão Francês', null), 'Comida');
  });

  test('retired categories map to their replacement', () {
    expect(PurchaseCategorizer.categorize('Ritalina', null), 'Saude');
    expect(
        PurchaseCategorizer.categorize('Creme dental', null), 'Pessoal');
    expect(PurchaseCategorizer.categorize('Arroz 5kg', null), 'Comida');
  });

  test('Comida splits into comida de verdade, junk e frutas', () {
    expect(PurchaseCategorizer.categorize('Macarrão', null), 'Comida');
    expect(PurchaseCategorizer.categorize('Feijão carioca', null),
        'Comida');
    expect(PurchaseCategorizer.categorize('Salgados', null),
        PurchaseCategorizer.junk);
    expect(PurchaseCategorizer.categorize('Coca cola 2L', null),
        PurchaseCategorizer.junk);
    expect(PurchaseCategorizer.categorize('Maçã', null), 'Frutas');
    expect(PurchaseCategorizer.categorize('Polpa de caju', null),
        'Frutas');
    // Keywords match anywhere in the item, first rule wins.
    expect(
        PurchaseCategorizer.categorize('Trufado de Nutella com fritas',
            null),
        PurchaseCategorizer.junk);
    // ...but a refrigerante flavored "laranja" is not a fruit.
    expect(PurchaseCategorizer.categorize('Monster laranja', null),
        PurchaseCategorizer.junk);
    // "doce" alone is junk, these are not.
    expect(PurchaseCategorizer.categorize('Batata doce', null), 'Comida');
    expect(PurchaseCategorizer.categorize('Páprica doce', null),
        'Comida');
  });

  test('higiene splits into Pessoal e Limpeza', () {
    expect(PurchaseCategorizer.categorize('Shampoo Dove', null),
        'Pessoal');
    expect(PurchaseCategorizer.categorize('Papel higiênico', null),
        'Pessoal');
    expect(PurchaseCategorizer.categorize('Sabão em pó 800g', null),
        'Limpeza');
    expect(PurchaseCategorizer.categorize('Detergente', null), 'Limpeza');
    // Sabonete is personal, not a cleaning product.
    expect(PurchaseCategorizer.categorize('2 sabonetes', null),
        'Pessoal');
  });

  test('construção keywords, with the short ones anchored', () {
    for (final item in [
      'Encanação',
      'Saco cimento',
      'Curva 25mm',
      'Corda de varal',
      'Portãozinho',
      'T',
      'Ponta parafusadeira',
      'Massa plástica',
      'Fita isolante',
      'Terra adubada',
    ]) {
      expect(PurchaseCategorizer.categorize(item, null), 'Construcao',
          reason: item);
    }
    // "cano" must not eat "canoeiro", "fio" must not eat "fio dental",
    // "luva" must not eat the disposable gloves from the pharmacy.
    expect(PurchaseCategorizer.categorize('Pula pula canoeiro', null),
        PurchaseCategorizer.lazer);
    expect(PurchaseCategorizer.categorize('Fio dental', null), 'Pessoal');
    expect(PurchaseCategorizer.categorize('Luvas descartáveis', null),
        'Saude');
    // Explicit exception to the generic "suporte" rule.
    expect(PurchaseCategorizer.categorize('Suporte TV', null), 'Casa');
  });

  test('lazer, beleza e brinquedos', () {
    for (final item in [
      'Ingressos parque',
      'Entrada cinema',
      'Cílios Carol',
      'Unha Carol',
      'Brinquedos Helena',
      'Almoço dia das mães',
      'Aniversário Alice',
      'Compra Shopee',
      'Uno',
    ]) {
      expect(PurchaseCategorizer.categorize(item, null),
          PurchaseCategorizer.lazer,
          reason: item);
    }
    // Whole words only: "concentrada" must not hit the "entrada" rule,
    // "luvas" must not hit the "uva" rule.
    expect(PurchaseCategorizer.categorize('Polpa concentrada', null),
        'Frutas');
    expect(PurchaseCategorizer.categorize('Luvas 20mm', null),
        'Construcao');
  });

  test('store hints categorize unknown items', () {
    expect(
        PurchaseCategorizer.categorize(
            'coisa qualquer', 'Larissa Construcoes'),
        'Construcao');
    expect(PurchaseCategorizer.categorize('coisa qualquer', 'Plastilandia'),
        'Casa');
  });

  test('exact matches', () {
    expect(PurchaseCategorizer.categorize('?', null), 'Outros');
    expect(PurchaseCategorizer.categorize('Tatu', null),
        PurchaseCategorizer.lazer);
  });

  test('unmatched items return null instead of Outros', () {
    expect(PurchaseCategorizer.categorize('zzz coisa misteriosa', null),
        isNull);
    expect(PurchaseCategorizer.categorize('', null), isNull);
    expect(PurchaseCategorizer.categorize('   ', 'Assaí'), isNull);
  });

  test('nameKey folds retired category names onto their replacement', () {
    expect(PurchaseCategorizer.nameKey('Alimentação'),
        PurchaseCategorizer.nameKey('Comida'));
    expect(PurchaseCategorizer.nameKey('Farmácia'),
        PurchaseCategorizer.nameKey('Saude'));
    expect(PurchaseCategorizer.nameKey('Higiene'),
        PurchaseCategorizer.nameKey('Pessoal'));
    expect(PurchaseCategorizer.nameKey('Lazer'),
        PurchaseCategorizer.nameKey(PurchaseCategorizer.lazer));
    expect(PurchaseCategorizer.nameKey('SERVIÇOS'),
        PurchaseCategorizer.nameKey('Servicos'));
    // Distinct categories must stay distinct.
    expect(PurchaseCategorizer.nameKey('Casa'),
        isNot(PurchaseCategorizer.nameKey('Limpeza')));
  });

  test('every rule category has a default color', () {
    // All categories the rules can produce must be creatable.
    final produced = <String>{
      for (final c in jsonDecode(
              File('test/fixtures/categorizer_cases.json')
                  .readAsStringSync()) as List<dynamic>)
        if (c['app'] != null) c['app'] as String,
    };
    for (final cat in produced) {
      expect(PurchaseCategorizer.categoryColors.containsKey(cat), isTrue,
          reason: 'Missing color for $cat');
    }
  });
}
