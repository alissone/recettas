import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/models/purchase.dart';
import 'package:recettas/models/purchase_category.dart';
import 'package:recettas/services/report_generator.dart';
import 'package:recettas/utils/brl.dart';

Purchase _p(String date, String item, double valor,
    {String? local, String? categoryId}) {
  return Purchase(
    id: item,
    userId: 'u1',
    purchaseDate: date,
    item: item,
    valor: valor,
    local: local,
    categoryId: categoryId,
  );
}

void main() {
  final categories = [
    const PurchaseCategory(
        id: 'c1', userId: 'u1', name: 'Essencial', colorValue: 0xFF81C784),
    const PurchaseCategory(
        id: 'c2', userId: 'u1', name: 'Supérfluo', colorValue: 0xFFFF8C42),
  ];

  final purchases = [
    _p('2026-06-02', 'Arroz 5kg', 32.90, local: 'Assaí', categoryId: 'c1'),
    _p('2026-06-02', 'Feijão', 8.50, local: 'Assaí', categoryId: 'c1'),
    _p('2026-06-05', 'Café 500g', 24.00, local: 'Atacadão', categoryId: 'c1'),
    _p('2026-06-05', 'Chocolate', 12.75, local: 'Atacadão', categoryId: 'c2'),
    _p('2026-06-10', 'Detergente <x> & "y"', 3.20, local: 'Assaí'),
    _p('2026-06-15', 'Gasolina', 150.00),
    _p('2026-06-28', 'Leite 1L', 5.99, local: 'Padaria', categoryId: 'c1'),
  ];

  String build() => ReportGenerator.buildMonthlyReport(
        month: DateTime(2026, 6),
        purchases: purchases,
        categories: categories,
        chartJs: '/* chart.js stub */',
      );

  test('renders cover, KPIs and fixed pages', () {
    final html = build();
    expect(html, contains('Gastos<br>Junho 2026'));

    final total = purchases.fold(0.0, (s, t) => s + t.valor);
    expect(html, contains(formatBrl(total)));

    // 7 fixed pages + 1 table page (7 txns < 30 per page).
    expect('class="page'.allMatches(html).length, 8);

    for (final id in [
      'chartDaily',
      'chartCumulative',
      'chartStores',
      'chartCatPie',
      'chartCatBar',
    ]) {
      expect(html, contains('getElementById(\'$id\')'));
    }
  });

  test('uses category names/colors and a fallback for uncategorized', () {
    final html = build();
    expect(html, contains('Essencial'));
    expect(html, contains('Supérfluo'));
    expect(html, contains('Sem categoria'));
    // ARGB 0xFF81C784 → #81c784.
    expect(html, contains('#81c784'));
  });

  test('escapes HTML in user data', () {
    final html = build();
    expect(html, contains('Detergente &lt;x&gt; &amp; &quot;y&quot;'));
    expect(html, isNot(contains('Detergente <x>')));
  });

  test('missing local groups under em dash', () {
    final html = build();
    expect(html, contains('<td>—</td>'));
  });

  test('dumps preview with real Chart.js for manual inspection', () {
    final chartJs = File('assets/chart.min.js').readAsStringSync();
    final html = ReportGenerator.buildMonthlyReport(
      month: DateTime(2026, 6),
      purchases: purchases,
      categories: categories,
      chartJs: chartJs,
    );
    final out = File('build/report_preview.html')
      ..createSync(recursive: true)
      ..writeAsStringSync(html);
    expect(out.existsSync(), isTrue);
  });
}
