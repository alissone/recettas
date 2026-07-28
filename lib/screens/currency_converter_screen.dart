import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

/// A convertible unit: [toBase] maps a value in this unit to the group's
/// base unit, [fromBase] maps a base-unit value back into this unit.
/// Linear for most units, affine for temperature (hence functions rather
/// than a single ratio).
class _Unit {
  final String code;
  final String label;
  final double Function(double) toBase;
  final double Function(double) fromBase;

  const _Unit(this.code, this.label, this.toBase, this.fromBase);
}

// Base unit: km/h.
const _speedUnits = [
  _Unit('KPH', 'km/h', _identity, _identity),
  _Unit('MPH', 'mph', _mphToKph, _kphToMph),
];

// Base unit: Kelvin.
const _tempUnits = [
  _Unit('C', '°C', _cToK, _kToC),
  _Unit('F', '°F', _fToK, _kToF),
  _Unit('K', 'K', _identity, _identity),
];

// Base unit: kg.
const _weightUnits = [
  _Unit('KG', 'kg', _identity, _identity),
  _Unit('LBS', 'lbs', _lbsToKg, _kgToLbs),
  _Unit('ST', 'stone', _stoneToKg, _kgToStone),
];

double _identity(double v) => v;
double _mphToKph(double v) => v * 1.609344;
double _kphToMph(double v) => v / 1.609344;
double _cToK(double v) => v + 273.15;
double _kToC(double v) => v - 273.15;
double _fToK(double v) => (v - 32) * 5 / 9 + 273.15;
double _kToF(double v) => (v - 273.15) * 9 / 5 + 32;
const _kgPerLb = 0.45359237;
double _lbsToKg(double v) => v * _kgPerLb;
double _kgToLbs(double v) => v / _kgPerLb;
const _kgPerStone = _kgPerLb * 14;
double _stoneToKg(double v) => v * _kgPerStone;
double _kgToStone(double v) => v / _kgPerStone;

/// Converts between BRL, USD and EUR (manual rates), plus fixed-ratio
/// unit boxes for speed, temperature and weight.
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
  bool _updatingRates = false;

  String _speedFrom = 'KPH';
  String _speedTo = 'MPH';
  final _speedAmountController = TextEditingController();

  String _tempFrom = 'C';
  String _tempTo = 'F';
  final _tempAmountController = TextEditingController();

  String _weightFrom = 'KG';
  String _weightTo = 'LBS';
  final _weightAmountController = TextEditingController();

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
    _speedAmountController.dispose();
    _tempAmountController.dispose();
    _weightAmountController.dispose();
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

  /// Pulls EUR→USD and EUR→BRL from Frankfurter, derives USD→BRL from
  /// them, and saves through [_saveRates] so it's cached for offline use.
  Future<void> _fetchRates() async {
    setState(() => _updatingRates = true);
    try {
      final res = await http
          .get(Uri.parse(
              'https://api.frankfurter.dev/v2/rates?base=EUR&quotes=USD,BRL'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final quotes = jsonDecode(res.body) as List<dynamic>;
      double? eurUsd;
      double? eurBrl;
      for (final entry in quotes) {
        final map = entry as Map<String, dynamic>;
        final rate = (map['rate'] as num?)?.toDouble();
        switch (map['quote']) {
          case 'USD':
            eurUsd = rate;
          case 'BRL':
            eurBrl = rate;
        }
      }
      if (eurUsd == null || eurUsd <= 0 || eurBrl == null || eurBrl <= 0) {
        throw Exception('Resposta inesperada da API');
      }
      _usdRateController.text = (eurBrl / eurUsd).toStringAsFixed(2);
      _eurRateController.text = eurBrl.toStringAsFixed(2);
      await _saveRates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cotações atualizadas')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao atualizar cotações: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingRates = false);
    }
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

  void _swapSpeed() {
    setState(() {
      final tmp = _speedFrom;
      _speedFrom = _speedTo;
      _speedTo = tmp;
    });
  }

  void _swapTemp() {
    setState(() {
      final tmp = _tempFrom;
      _tempFrom = _tempTo;
      _tempTo = tmp;
    });
  }

  void _swapWeight() {
    setState(() {
      final tmp = _weightFrom;
      _weightFrom = _weightTo;
      _weightTo = tmp;
    });
  }

  double? _convertUnit(
      List<_Unit> units, String fromCode, String toCode, String text) {
    final amount = _parseNumber(text);
    if (amount == null) return null;
    final from = units.firstWhere((u) => u.code == fromCode);
    final to = units.firstWhere((u) => u.code == toCode);
    return to.fromBase(from.toBase(amount));
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
                      border:
                          Border.all(color: AppTheme.borderOrange),
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
                    child: OutlinedButton.icon(
                      onPressed: _updatingRates ? null : _fetchRates,
                      icon: _updatingRates
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined,
                              size: 18),
                      label: Text(_updatingRates
                          ? 'Atualizando...'
                          : 'Atualizar cotações'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryOrange,
                        side: const BorderSide(
                            color: AppTheme.primaryOrange),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            _buildUnitConverterCard(
              title: 'Velocidade',
              units: _speedUnits,
              amountController: _speedAmountController,
              from: _speedFrom,
              to: _speedTo,
              onFromChanged: (v) => setState(() => _speedFrom = v),
              onToChanged: (v) => setState(() => _speedTo = v),
              onSwap: _swapSpeed,
            ),
            const SizedBox(height: 20),
            _buildUnitConverterCard(
              title: 'Temperatura',
              units: _tempUnits,
              amountController: _tempAmountController,
              from: _tempFrom,
              to: _tempTo,
              onFromChanged: (v) => setState(() => _tempFrom = v),
              onToChanged: (v) => setState(() => _tempTo = v),
              onSwap: _swapTemp,
              allowNegative: true,
            ),
            const SizedBox(height: 20),
            _buildUnitConverterCard(
              title: 'Peso',
              units: _weightUnits,
              amountController: _weightAmountController,
              from: _weightFrom,
              to: _weightTo,
              onFromChanged: (v) => setState(() => _weightFrom = v),
              onToChanged: (v) => setState(() => _weightTo = v),
              onSwap: _swapWeight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitConverterCard({
    required String title,
    required List<_Unit> units,
    required TextEditingController amountController,
    required String from,
    required String to,
    required ValueChanged<String> onFromChanged,
    required ValueChanged<String> onToChanged,
    required VoidCallback onSwap,
    bool allowNegative = false,
  }) {
    final result = _convertUnit(units, from, to, amountController.text);
    final toUnit = units.firstWhere((u) => u.code == to);
    return _buildCard(
      title: title,
      child: Column(
        children: [
          TextField(
            controller: amountController,
            keyboardType: TextInputType.numberWithOptions(
                decimal: true, signed: allowNegative),
            style: AppTheme.valueBold.copyWith(fontSize: 20),
            decoration: _inputDecoration('Valor'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildUnitDropdown(
                      units, from, 'De', onFromChanged)),
              IconButton(
                onPressed: onSwap,
                icon: const Icon(Icons.swap_horiz,
                    color: AppTheme.primaryOrange),
                tooltip: 'Inverter',
              ),
              Expanded(
                  child:
                      _buildUnitDropdown(units, to, 'Para', onToChanged)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.borderOrange),
            ),
            child: Column(
              children: [
                Text('$from → $to', style: AppTheme.caption),
                const SizedBox(height: 4),
                Text(
                  result != null
                      ? '${result.toStringAsFixed(2)} ${toUnit.label}'
                      : '—',
                  style: AppTheme.headingMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown(List<_Unit> units, String value, String label,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey('${label}_$value'),
      initialValue: value,
      decoration: _inputDecoration(label),
      items: [
        for (final u in units)
          DropdownMenuItem(value: u.code, child: Text(u.label)),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
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
