/// Injected into the product page webview via
/// `WebViewController.runJavaScriptReturningResult`. Reads the real DOM
/// instead of the markdown dump `scripts/product_page_to_sql.py` expects -
/// every `<table>` on the page as rows of cell text, plus the page title and
/// full visible text, so `ProductPageParser` can apply the same
/// identification logic (find the "Marca" row, find "Tabela nutricional" +
/// "Porção de N g", split a value cell) against live data instead of pasted
/// text. Ends in `JSON.stringify(...)` as the final expression, which is
/// what `runJavaScriptReturningResult` returns.
const String kProductExtractionJs = '''
(function() {
  var title = (document.querySelector('h1') || {}).innerText || document.title || '';
  var bodyText = document.body ? document.body.innerText : '';
  var tables = Array.from(document.querySelectorAll('table')).map(function(t) {
    return Array.from(t.querySelectorAll('tr')).map(function(tr) {
      return Array.from(tr.querySelectorAll('td,th')).map(function(cell) {
        return (cell.innerText || '').trim();
      });
    });
  });
  return JSON.stringify({ title: title, bodyText: bodyText, tables: tables });
})();
''';
