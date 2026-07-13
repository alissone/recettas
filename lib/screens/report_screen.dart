import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../models/purchase.dart';
import '../models/purchase_category.dart';
import '../services/report_generator.dart';
import '../services/supabase_service.dart';

/// Monthly expense report: the HTML built by ReportGenerator rendered in
/// a WebView. On desktop (no webview_flutter implementation) offers to
/// open the report in the default browser instead.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  /// Chart.js source, loaded once per app run.
  static String? _chartJs;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  bool _isEmpty = false;
  String? _error;
  String? _html;
  WebViewController? _controller;

  static bool get _webViewSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  String get _monthLabel =>
      '${_monthNames[_month.month - 1]} ${_month.year}';

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    if (_webViewSupported) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFCCCCCC));
    }
    _load();
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Entre na sua conta para gerar relatórios.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _isEmpty = false;
      _error = null;
    });
    try {
      _chartJs ??= await rootBundle.loadString('assets/chart.min.js');
      final results = await Future.wait([
        SupabaseService.getPurchases(
          fromDate: _dateString(_month),
          toDateExclusive:
              _dateString(DateTime(_month.year, _month.month + 1)),
        ),
        SupabaseService.getPurchaseCategories(),
      ]);
      if (!mounted) return;
      final purchases = results[0] as List<Purchase>;
      if (purchases.isEmpty) {
        setState(() {
          _isLoading = false;
          _isEmpty = true;
        });
        return;
      }
      _html = ReportGenerator.buildMonthlyReport(
        month: _month,
        purchases: purchases,
        categories: results[1] as List<PurchaseCategory>,
        chartJs: _chartJs!,
      );
      await _controller?.loadHtmlString(_html!);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Erro ao gerar relatório: $e';
        });
      }
    }
  }

  /// Desktop fallback: write the HTML to a temp file and open it in the
  /// default browser (where it can also be printed / saved as PDF).
  Future<void> _openInBrowser() async {
    final html = _html;
    if (html == null) return;
    final path = '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}relatorio_'
        '${_dateString(_month).substring(0, 7)}.html';
    await File(path).writeAsString(html);
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
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        foregroundColor: AppTheme.darkBrown,
        elevation: 0,
        title: const Text('Relatório de gastos',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.mediumBrown),
              onPressed: _isLoading ? null : () => _changeMonth(-1),
            ),
            Expanded(
              child: Text(
                _monthLabel,
                textAlign: TextAlign.center,
                style: AppTheme.sectionTitle,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right,
                  color: AppTheme.mediumBrown),
              onPressed: _isLoading ? null : () => _changeMonth(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }
    if (_error != null) return _buildMessage(Icons.error_outline, _error!);
    if (_isEmpty) {
      return _buildMessage(
          Icons.receipt_long_outlined, 'Sem compras em $_monthLabel.');
    }
    if (_controller != null) return WebViewWidget(controller: _controller!);

    // Desktop: no webview implementation, open externally.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Relatório de $_monthLabel gerado.',
              style: AppTheme.bodyText),
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

  Widget _buildMessage(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.mediumBrown),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center, style: AppTheme.bodyText),
          ],
        ),
      ),
    );
  }
}
