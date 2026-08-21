import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import 'extraction_js.dart';

/// The raw DOM data pulled from the current webview page by
/// [kProductExtractionJs] - title, full visible text, and every `<table>`
/// as rows of cell text.
class ExtractedPage {
  final String title;
  final String bodyText;
  final List<List<List<String>>> tables;

  const ExtractedPage({
    required this.title,
    required this.bodyText,
    required this.tables,
  });
}

/// Runs [kProductExtractionJs] in the webview and decodes the result.
class ProductPageExtractor {
  ProductPageExtractor._();

  static Future<ExtractedPage> extract(WebViewController controller) async {
    final raw = await controller.runJavaScriptReturningResult(
      kProductExtractionJs,
    );
    final json = _decode(raw);
    final tables = (json['tables'] as List? ?? const [])
        .map((table) => (table as List? ?? const [])
            .map((row) => (row as List? ?? const [])
                .map((cell) => cell.toString())
                .toList())
            .toList())
        .toList();
    return ExtractedPage(
      title: (json['title'] ?? '').toString(),
      bodyText: (json['bodyText'] ?? '').toString(),
      tables: tables,
    );
  }

  /// [runJavaScriptReturningResult] is inconsistent across platforms: iOS
  /// can hand back an already-decoded Map, while Android is known to wrap
  /// the JSON string our JS returns in an extra layer of quoting/escaping.
  /// Unverified against a real Android build - adjust here if the on-device
  /// pass finds a different shape.
  static Map<String, dynamic> _decode(Object? raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is! String) {
      throw FormatException('Não foi possível ler a página (tipo $raw).');
    }
    var text = raw;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, dynamic>();
      if (decoded is String) {
        // Double-encoded: the outer decode only unwrapped the string.
        final inner = jsonDecode(decoded);
        if (inner is Map) return inner.cast<String, dynamic>();
      }
    } catch (_) {
      // Fall through to the manual unwrap below.
    }
    if (text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1).replaceAll(r'\"', '"');
      final decoded = jsonDecode(text);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    throw const FormatException('Não foi possível ler a página.');
  }
}
