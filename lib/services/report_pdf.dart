import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Turns a report's self-contained HTML (A4 pages, `@page { margin: 0 }`)
/// into PDF bytes, then prints or saves them.
///
/// The HTML must not rely on JavaScript: on Android/iOS/macOS the
/// conversion is printing's convertHtml, which loads the page in a
/// WebView with JavaScript off. Windows has no such converter, so there
/// the page goes through headless Edge (always installed on Windows 10+).
class ReportPdf {
  ReportPdf._();

  /// A4 with no margins: the pages carry their own.
  static final _a4 = PdfPageFormat.a4.copyWith(
    marginTop: 0,
    marginBottom: 0,
    marginLeft: 0,
    marginRight: 0,
  );

  static Future<Uint8List> fromHtml(String html) async {
    if (Platform.isWindows) return _viaEdge(html);
    // Deprecated upstream "in favour of building the PDF with widgets",
    // but it is the only HTML -> PDF path on mobile and it still works.
    // ignore: deprecated_member_use
    return Printing.convertHtml(html: html, format: _a4);
  }

  /// The system print dialog, which also offers "Save as PDF".
  static Future<void> printPdf(Uint8List bytes, String name) async {
    await Printing.layoutPdf(
      name: name,
      format: _a4,
      onLayout: (_) async => bytes,
    );
  }

  /// Mobile: the share sheet (save to Files/Drive, send...). Windows:
  /// writes the file to Downloads and opens it. Returns the saved path
  /// on Windows, null elsewhere.
  static Future<String?> savePdf(Uint8List bytes, String fileName) async {
    if (!Platform.isWindows) {
      await Printing.sharePdf(bytes: bytes, filename: '$fileName.pdf');
      return null;
    }
    final dir = await getDownloadsDirectory() ?? Directory.systemTemp;
    final path = '${dir.path}${Platform.pathSeparator}$fileName.pdf';
    await File(path).writeAsBytes(bytes);
    await Process.run('cmd', ['/c', 'start', '', path]);
    return path;
  }

  static Future<Uint8List> _viaEdge(String html) async {
    final edge = [
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
      r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    ].where((p) => File(p).existsSync()).firstOrNull;
    if (edge == null) {
      throw Exception('Microsoft Edge não encontrado para gerar o PDF.');
    }

    final dir = await Directory.systemTemp.createTemp('relatorio_');
    try {
      final htmlFile = File('${dir.path}${Platform.pathSeparator}r.html');
      final pdfFile = File('${dir.path}${Platform.pathSeparator}r.pdf');
      await htmlFile.writeAsString(html);
      final result = await Process.run(edge, [
        '--headless=new',
        '--disable-gpu',
        '--no-pdf-header-footer',
        '--user-data-dir=${dir.path}${Platform.pathSeparator}profile',
        '--print-to-pdf=${pdfFile.path}',
        htmlFile.uri.toString(),
      ]);
      if (!await pdfFile.exists()) {
        throw Exception('Edge não gerou o PDF: ${result.stderr}');
      }
      return await pdfFile.readAsBytes();
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Edge may still hold the profile dir for a moment; it's temp.
      }
    }
  }
}
