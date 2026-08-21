import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../services/product_page_extractor.dart';
import '../services/product_page_parser.dart';
import '../services/supabase_service.dart';
import '../models/scanned_product.dart';
import 'product_scanner_confirm_screen.dart';

/// Embedded Extra Mercado browser: the user navigates freely to a product
/// page, then "Extrair dados" reads the page's DOM (via
/// ProductPageExtractor/ProductPageParser) and, if a nutrition table was
/// found, opens ProductScannerConfirmScreen to review and save it. Nothing
/// is written from this screen.
class ProductScannerScreen extends StatefulWidget {
  const ProductScannerScreen({super.key});

  @override
  State<ProductScannerScreen> createState() => _ProductScannerScreenState();
}

class _ProductScannerScreenState extends State<ProductScannerScreen> {
  static const _startUrl = 'https://www.extramercado.com.br';

  WebViewController? _controller;
  bool _isExtracting = false;

  static bool get _webViewSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_webViewSupported) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(_startUrl));
    }
  }

  Future<void> _extract() async {
    final controller = _controller;
    if (controller == null || _isExtracting) return;

    setState(() => _isExtracting = true);
    try {
      final page = await ProductPageExtractor.extract(controller);
      final catalogList = await SupabaseService.getNutrientCatalog();
      final catalog = {for (final n in catalogList) n.id: n};
      final parsed = ProductPageParser.parseNutritionTable(page, catalog);

      if (parsed == null || parsed.rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não encontrei uma tabela nutricional reconhecível '
                'nesta página.'),
          ));
        }
        return;
      }

      final sourceUrl = await controller.currentUrl() ?? _startUrl;
      final title = page.title.trim();
      final scanned = ScannedProduct(
        name: title.isEmpty ? 'Produto sem nome' : title,
        brand: ProductPageParser.findBrand(page.tables),
        code: ProductPageParser.findCode(page.bodyText),
        sourceUrl: sourceUrl,
        nutrition: parsed,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductScannerConfirmScreen(
            product: scanned,
            catalog: catalog,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao extrair: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
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
        title: const Text('Escanear produto',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller!.reload(),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _controller == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExtracting ? null : _extract,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                    ),
                    icon: _isExtracting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.qr_code_scanner),
                    label: Text(
                        _isExtracting ? 'Extraindo...' : 'Extrair dados'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    final controller = _controller;
    if (controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.desktop_access_disabled,
                  size: 48, color: AppTheme.mediumBrown),
              const SizedBox(height: 12),
              Text(
                'Escanear produto não está disponível nesta plataforma.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyText,
              ),
            ],
          ),
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }
}
