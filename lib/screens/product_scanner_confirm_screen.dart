import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../models/nutrient.dart';
import '../models/scanned_product.dart';
import '../services/product_page_parser.dart';
import '../services/supabase_service.dart';

/// Review step before writing a scanned product to Supabase. Name and
/// brand are editable; the parsed portion and recognized nutrients are
/// shown as scanned. Nothing is written until "Salvar" is pressed.
class ProductScannerConfirmScreen extends StatefulWidget {
  final ScannedProduct product;
  final Map<NutrientId, Nutrient> catalog;

  const ProductScannerConfirmScreen({
    super.key,
    required this.product,
    required this.catalog,
  });

  @override
  State<ProductScannerConfirmScreen> createState() =>
      _ProductScannerConfirmScreenState();
}

class _ProductScannerConfirmScreenState
    extends State<ProductScannerConfirmScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.product.name);
  late final TextEditingController _brandController =
      TextEditingController(text: widget.product.brand ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o nome do produto.')));
      return;
    }
    final brand = _brandController.text.trim();
    final nutrition = widget.product.nutrition;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.upsertScannedFood(
        foodId: ProductPageParser.foodUuidFor(name),
        name: name,
        brand: brand.isEmpty ? null : brand,
        baseAmount: nutrition.baseAmount,
        baseUnit: nutrition.baseUnit,
        nutrients: nutrition.rows,
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = e.code == '42501'
          ? 'Já existe um alimento com esse nome que você não pode editar '
              'por aqui.'
          : 'Erro ao salvar: ${e.message}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = widget.product.nutrition;
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.creamBackground,
        foregroundColor: AppTheme.darkBrown,
        elevation: 0,
        title: const Text('Confirmar produto',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brandController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Marca (opcional)'),
          ),
          const SizedBox(height: 16),
          Text(
            'Porção de ${formatQuantity(nutrition.baseAmount)} '
            '${nutrition.baseUnit}',
            style: AppTheme.sectionTitle,
          ),
          if (widget.product.code != null) ...[
            const SizedBox(height: 2),
            Text('Código: ${widget.product.code}', style: AppTheme.caption),
          ],
          const SizedBox(height: 12),
          _buildNutrientsCard(nutrition),
          if (nutrition.unknownLabels.isNotEmpty ||
              nutrition.skippedNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildWarningsCard(nutrition),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.mediumBrown,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ),
                  child: Text(_isSaving ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientsCard(ParsedProduct nutrition) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nutrientes reconhecidos (${nutrition.rows.length})',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          for (final row in nutrition.rows) _buildNutrientRow(row),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(ParsedNutritionRow row) {
    final unitLabel = widget.catalog[row.nutrientId]?.unitLabel ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(row.label, style: AppTheme.bodyText)),
          Text('${formatNutrientAmount(row.amount)} $unitLabel',
              style: AppTheme.valueBold),
        ],
      ),
    );
  }

  Widget _buildWarningsCard(ParsedProduct nutrition) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppTheme.primaryOrange),
              SizedBox(width: 6),
              Text('Não importados', style: AppTheme.sectionTitle),
            ],
          ),
          const SizedBox(height: 8),
          for (final label in nutrition.unknownLabels)
            Text('• Não reconhecido: $label',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w400)),
          for (final note in nutrition.skippedNotes)
            Text('• $note',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
