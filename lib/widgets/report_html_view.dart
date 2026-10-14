import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';

/// Shows a generated HTML report: in a WebView where webview_flutter has
/// an implementation, otherwise (desktop) as a button that writes it to a
/// temp file and opens it in the default browser - where it can also be
/// printed or saved as PDF.
class ReportHtmlView extends StatefulWidget {
  final String html;

  /// Temp file name for the desktop fallback, without extension.
  final String fileName;

  const ReportHtmlView({
    super.key,
    required this.html,
    required this.fileName,
  });

  static bool get webViewSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  State<ReportHtmlView> createState() => _ReportHtmlViewState();
}

class _ReportHtmlViewState extends State<ReportHtmlView> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (ReportHtmlView.webViewSupported) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFCCCCCC))
        ..loadHtmlString(widget.html);
    }
  }

  @override
  void didUpdateWidget(ReportHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _controller?.loadHtmlString(widget.html);
    }
  }

  Future<void> _openInBrowser() async {
    final path = '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}${widget.fileName}.html';
    await File(path).writeAsString(widget.html);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) return WebViewWidget(controller: _controller!);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Relatório gerado.', style: AppTheme.bodyText),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Abrir no navegador'),
          ),
        ],
      ),
    );
  }
}
