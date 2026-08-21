import '../services/product_page_parser.dart';

/// Holds a scanned product between [ProductScannerScreen] and
/// [ProductScannerConfirmScreen]. [name]/[brand] are mutable since the
/// confirm screen lets the user fix them before saving.
class ScannedProduct {
  String name;
  String? brand;
  final String? code;
  final String sourceUrl;
  final ParsedProduct nutrition;

  ScannedProduct({
    required this.name,
    this.brand,
    this.code,
    required this.sourceUrl,
    required this.nutrition,
  });
}
