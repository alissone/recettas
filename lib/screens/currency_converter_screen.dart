import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

/// Converts between BRL, USD and EUR. Rates are entered manually and
/// kept in shared preferences (both quoted in BRL).
class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState
    extends State<CurrencyConverterScreen> {
  static const _usdKey = 'currency_rate_usd_brl';
  static const _eurKey = 'currency_rate_eur_brl';

  // BRL per unit of each currency.
  double _usdBrl = 5.30;
  double _eurBrl = 6.20;

  String _from = 'BRL';
  String _to = 'USD';

  final _amountController = TextEditingController();
  final _usdRateController = TextEditingController();
  final _eurRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _usdRateController.dispose();
    _eurRateController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usdBrl = prefs.getDouble(_usdKey) ?? _usdBrl;
      _eurBrl = prefs.getDouble(_eurKey) ?? _eurBrl;
      _usdRateController.text = _usdBrl.toStringAsFixed(2);
      _eurRateController.text = _eurBrl.toStringAsFixed(2);
    });
  }

  Future<void> _saveRates() async {
    final usd = _parseNumber(_usdRateController.text);
    final eur = _parseNumber(_eurRateController.text);
    if (usd == null || usd <= 0 || eur == null || eur <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_usdKey, usd);
    await prefs.setDouble(_eurKey, eur);
    setState(() {
      _usdBrl = usd;
      _eurBrl = eur;
    });
    if (mounted) FocusScope.of(context).unfocus();
  }

  /// Accepts both "5.30" and "5,30".
  double? _parseNumber(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  double _toBrl(String currency) {
    switch (currency) {
      case 'USD':
        return _usdBrl;
      case 'EUR':
        return _eurBrl;
      default:
        return 1.0;
    }
  }

  double? get _converted {
    final amount = _parseNumber(_amountController.text);
    if (amount == null) return null;
    return amount * _toBrl(_from) / _toBrl(_to);
  }

  String _symbol(String currency) {
    switch (currency) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      default:
        return r'R$';
    }
  }

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _converted;
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Conversor de moedas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildCard(
              title: 'Converter',
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: AppTheme.valueBold.copyWith(fontSize: 20),
                    decoration: _inputDecoration('Valor'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildCurrencyDropdown(true)),
                      IconButton(
                        onPressed: _swap,
                        icon: const Icon(Icons.swap_horiz,
                            color: AppTheme.primaryOrange),
                        tooltip: 'Inverter',
                      ),
                      Expanded(child: _buildCurrencyDropdown(false)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                          color: AppTheme.primaryOrange
                              .withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Text('$_from → $_to', style: AppTheme.caption),
                        const SizedBox(height: 4),
                        Text(
                          result != null
                              ? '${_symbol(_to)} '
                                  '${result.toStringAsFixed(2)}'
                              : '—',
                          style: AppTheme.headingMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: 'Cotações (atualização manual)',
              child: Column(
                children: [
                  _buildRateField('1 USD em BRL', _usdRateController),
                  const SizedBox(height: 12),
                  _buildRateField('1 EUR em BRL', _eurRateController),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveRates,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Salvar cotações'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
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
          Text(title, style: AppTheme.sectionTitle),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(bool isFrom) {
    // Keyed on the value so the swap button rebuilds the field with
    // the new selection.
    return DropdownButtonFormField<String>(
      key: ValueKey('${isFrom ? 'from' : 'to'}-${isFrom ? _from : _to}'),
      initialValue: isFrom ? _from : _to,
      decoration: _inputDecoration(isFrom ? 'De' : 'Para'),
      items: const [
        DropdownMenuItem(value: 'BRL', child: Text('🇧🇷 BRL')),
        DropdownMenuItem(value: 'USD', child: Text('🇺🇸 USD')),
        DropdownMenuItem(value: 'EUR', child: Text('🇪🇺 EUR')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          if (isFrom) {
            _from = v;
          } else {
            _to = v;
          }
        });
      },
    );
  }

  Widget _buildRateField(String label, TextEditingController controller) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTheme.bodyText)),
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: _inputDecoration(null),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String? label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.mediumBrown),
      filled: true,
      fillColor: AppTheme.creamBackground,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide:
            const BorderSide(color: AppTheme.primaryOrange, width: 2),
      ),
    );
  }
}
