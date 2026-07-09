import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';

/// Adds or subtracts two hh:mm:ss times, wrapping the result to a time
/// of day; crossing midnight is shown as a ±N dia(s) indicator.
/// Minutes and seconds may exceed 59 (e.g. 14:15 + 0:180:00).
class TimeCalculatorScreen extends StatefulWidget {
  const TimeCalculatorScreen({super.key});

  @override
  State<TimeCalculatorScreen> createState() =>
      _TimeCalculatorScreenState();
}

class _TimeCalculatorScreenState extends State<TimeCalculatorScreen> {
  bool _isAddition = true;

  final _controllers = List.generate(6, (_) => TextEditingController());

  TextEditingController _ctrl(int row, int field) =>
      _controllers[row * 3 + field];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  int _rowSeconds(int row) {
    final h = int.tryParse(_ctrl(row, 0).text) ?? 0;
    final m = int.tryParse(_ctrl(row, 1).text) ?? 0;
    final s = int.tryParse(_ctrl(row, 2).text) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  static const _daySeconds = 24 * 3600;

  int get _totalSeconds {
    final a = _rowSeconds(0);
    final b = _rowSeconds(1);
    return _isAddition ? a + b : a - b;
  }

  /// Days crossed when the raw total falls outside 00:00–24:00.
  int get _dayOffset => (_totalSeconds / _daySeconds).floor();

  String get _result {
    // Dart's % is never negative for a positive divisor, so 02:00 −
    // 05:00 wraps to 21:00 (with _dayOffset −1) rather than −03:00.
    final wrapped = _totalSeconds % _daySeconds;
    final h = wrapped ~/ 3600;
    final m = (wrapped % 3600) ~/ 60;
    final s = wrapped % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Calculadora de horas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  _buildTimeRow(0),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('+')),
                      ButtonSegment(value: false, label: Text('−')),
                    ],
                    selected: {_isAddition},
                    onSelectionChanged: (s) =>
                        setState(() => _isAddition = s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppTheme.primaryOrange
                          .withValues(alpha: 0.15),
                      selectedForegroundColor: AppTheme.primaryOrange,
                      side: BorderSide(color: AppTheme.borderOrange),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTimeRow(1),
                  const SizedBox(height: 20),
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
                        const Text('Resultado', style: AppTheme.caption),
                        const SizedBox(height: 4),
                        Text(
                          _result,
                          style: AppTheme.headingMedium
                              .copyWith(fontFeatures: const [
                            FontFeature.tabularFigures()
                          ]),
                        ),
                        if (_dayOffset != 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_dayOffset > 0 ? '+' : '−'}'
                            '${_dayOffset.abs()} '
                            'dia${_dayOffset.abs() == 1 ? '' : 's'}',
                            style: AppTheme.caption.copyWith(
                                color: AppTheme.primaryOrange),
                          ),
                        ],
                      ],
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

  Widget _buildTimeRow(int row) {
    return Row(
      children: [
        _buildField(row, 0, 'hh'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(':', style: AppTheme.headingMedium),
        ),
        _buildField(row, 1, 'mm'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(':', style: AppTheme.headingMedium),
        ),
        _buildField(row, 2, 'ss'),
      ],
    );
  }

  Widget _buildField(int row, int field, String hint) {
    return Expanded(
      child: TextField(
        controller: _ctrl(row, field),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          // Minutes and seconds may go past 59 (e.g. +180 minutes).
          LengthLimitingTextInputFormatter(4),
        ],
        textAlign: TextAlign.center,
        style: AppTheme.valueBold.copyWith(fontSize: 20),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: AppTheme.mediumBrown.withValues(alpha: 0.4)),
          filled: true,
          fillColor: AppTheme.creamBackground,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            borderSide: const BorderSide(
                color: AppTheme.primaryOrange, width: 2),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
