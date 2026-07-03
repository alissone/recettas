import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/services/receipt_csv_parser.dart';
import 'package:recettas/utils/brl.dart';

void main() {
  group('ReceiptCsvParser', () {
    test('parses clean CSV with header', () {
      const raw = '''
NOME,QUANTIDADE,VALOR UNITARIO,DATA,ESTABELECIMENTO
ARROZ 5KG,1,25.90,2026-06-28,SUPERMERCADO BOM PRECO
BANANA PRATA,0.75,7.99,2026-06-28,SUPERMERCADO BOM PRECO''';
      final items = ReceiptCsvParser.parse(raw);
      expect(items, hasLength(2));
      expect(items[0].nome, 'ARROZ 5KG');
      expect(items[0].valorUnitario, 25.90);
      expect(items[0].data, '2026-06-28');
      expect(items[1].quantidade, 0.75);
      expect(items[1].valorTotal, 5.99);
    });

    test('strips code fences and think blocks', () {
      const raw = '''
<think>analisando o cupom</think>
```csv
NOME,QUANTIDADE,VALOR UNITARIO,DATA,ESTABELECIMENTO
CAFE,1,18.50,28/06/2026,MERCADO X
```''';
      final items = ReceiptCsvParser.parse(raw);
      expect(items, hasLength(1));
      expect(items[0].nome, 'CAFE');
      expect(items[0].data, '2026-06-28');
    });

    test('fixes decimal commas splitting VALOR into extra fields', () {
      final fixed = ReceiptCsvParser.fixDecimalCommas(
          ['LEITE', '2', '3', '29', '28/06/2026', 'MERCADO']);
      expect(fixed, ['LEITE', '2', '3.29', '28/06/2026', 'MERCADO']);
    });

    test('normalizes semicolon delimiter', () {
      const raw = '''
NOME;QUANTIDADE;VALOR UNITARIO;DATA;ESTABELECIMENTO
PAO;2;0.85;01/07/2026;PADARIA''';
      final items = ReceiptCsvParser.parse(raw);
      expect(items, hasLength(1));
      expect(items[0].valorTotal, 1.70);
      expect(items[0].data, '2026-07-01');
    });

    test('invalid dates become empty so callers can fall back', () {
      const raw = '''
NOME,QUANTIDADE,VALOR UNITARIO,DATA,ESTABELECIMENTO
SABAO,1,10.00,sem data,MERCADO''';
      final items = ReceiptCsvParser.parse(raw);
      expect(items.single.data, '');
    });
  });

  group('brl', () {
    test('formats with thousands separator', () {
      expect(formatBrl(1234.5), 'R\$ 1.234,50');
      expect(formatBrl(3.29), 'R\$ 3,29');
    });

    test('parses Brazilian and plain input', () {
      expect(parseBrlInput('1.234,56'), 1234.56);
      expect(parseBrlInput('12,34'), 12.34);
      expect(parseBrlInput('12.34'), 12.34);
      expect(parseBrlInput('R\$ 5'), 5);
      expect(parseBrlInput('abc'), isNull);
    });
  });
}
