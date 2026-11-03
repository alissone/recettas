import 'package:flutter_test/flutter_test.dart';
import 'package:recettas/utils/links.dart';

void main() {
  test('a todo that is only a link', () {
    expect(Links.extract('https://example.com/a?b=1'),
        ['https://example.com/a?b=1']);
  });

  test('bare links in text, trailing punctuation dropped', () {
    expect(Links.extract('Ler https://a.com/x. Depois www.b.com.br, ok?'),
        ['https://a.com/x', 'www.b.com.br']);
  });

  test('markdown link targets, without duplicates', () {
    expect(
        Links.extract('[Receita](https://r.com/bolo) e https://r.com/bolo '
            'e [outro](https://o.com "título")'),
        ['https://r.com/bolo', 'https://o.com']);
  });

  test('no link', () {
    expect(Links.extract('Comprar pão @today'), isEmpty);
  });

  test('toUri adds https to www and rejects other schemes', () {
    expect(Links.toUri('www.x.com').toString(), 'https://www.x.com');
    expect(Links.toUri('javascript:alert(1)'), isNull);
    expect(Links.toUri('mailto:a@b.com'), isNotNull);
  });
}
