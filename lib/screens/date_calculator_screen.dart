import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Two tools: add/subtract days, months or years from a date, and the
/// difference between two dates.
class DateCalculatorScreen extends StatefulWidget {
  const DateCalculatorScreen({super.key});

  @override
  State<DateCalculatorScreen> createState() =>
      _DateCalculatorScreenState();
}

class _DateCalculatorScreenState extends State<DateCalculatorScreen> {
  // --- Add/subtract state ---
  DateTime _baseDate = DateTime.now();
  bool _isAddition = true;
  int _amount = 1;
  String _unit = 'dias'; // dias | meses | anos
  final _amountController = TextEditingController(text: '1');

  // --- Difference state ---
  DateTime _diffStart = DateTime.now();
  DateTime _diffEnd = DateTime.now();

  static const _weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Month/year arithmetic clamped to the last valid day, so
  /// Jan 31 + 1 month = Feb 28/29 instead of Mar 3.
  DateTime _addMonths(DateTime date, int months) {
    final total = date.year * 12 + (date.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
  }

  DateTime get _resultDate {
    final n = _isAddition ? _amount : -_amount;
    switch (_unit) {
      case 'meses':
        return _addMonths(_baseDate, n);
      case 'anos':
        return _addMonths(_baseDate, n * 12);
      default:
        return DateTime(
            _baseDate.year, _baseDate.month, _baseDate.day + n);
    }
  }

  int get _diffDays {
    final a = DateTime(_diffStart.year, _diffStart.month, _diffStart.day);
    final b = DateTime(_diffEnd.year, _diffEnd.month, _diffEnd.day);
    return b.difference(a).inDays;
  }

  /// Breaks the difference into whole years, months and days.
  (int, int, int) get _diffBreakdown {
    var a = DateTime(_diffStart.year, _diffStart.month, _diffStart.day);
    var b = DateTime(_diffEnd.year, _diffEnd.month, _diffEnd.day);
    if (b.isBefore(a)) (a, b) = (b, a);

    var years = b.year - a.year;
    var months = b.month - a.month;
    var days = b.day - a.day;
    if (days < 0) {
      months--;
      days += DateTime(b.year, b.month, 0).day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    return (years, months, days);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(
      DateTime current, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Calculadora de datas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildCard(
              title: 'Somar ou subtrair',
              child: _buildAddSubtract(),
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: 'Diferença entre datas',
              child: _buildDifference(),
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

  Widget _buildAddSubtract() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateField('Data inicial', _baseDate,
            (d) => setState(() => _baseDate = d)),
        const SizedBox(height: 12),
        Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('+')),
                ButtonSegment(value: false, label: Text('−')),
              ],
              selected: {_isAddition},
              onSelectionChanged: (s) =>
                  setState(() => _isAddition = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    AppTheme.primaryOrange.withValues(alpha: 0.15),
                selectedForegroundColor: AppTheme.primaryOrange,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: _inputDecoration(),
                onChanged: (v) => setState(
                    () => _amount = int.tryParse(v)?.abs() ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'dias', child: Text('dias')),
                  DropdownMenuItem(value: 'meses', child: Text('meses')),
                  DropdownMenuItem(value: 'anos', child: Text('anos')),
                ],
                onChanged: (v) => setState(() => _unit = v ?? 'dias'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildResultBox(
          '${_formatDate(_resultDate)}  ·  '
          '${_weekdays[_resultDate.weekday - 1]}',
        ),
      ],
    );
  }

  Widget _buildDifference() {
    final days = _diffDays;
    final (years, months, remDays) = _diffBreakdown;
    final parts = <String>[
      if (years > 0) '$years ano${years == 1 ? '' : 's'}',
      if (months > 0) '$months mes${months == 1 ? '' : 'es'}',
      if (remDays > 0 || (years == 0 && months == 0))
        '$remDays dia${remDays == 1 ? '' : 's'}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateField('De', _diffStart,
            (d) => setState(() => _diffStart = d)),
        const SizedBox(height: 12),
        _buildDateField(
            'Até', _diffEnd, (d) => setState(() => _diffEnd = d)),
        const SizedBox(height: 16),
        _buildResultBox(
          '${days.abs()} dia${days.abs() == 1 ? '' : 's'}'
          '${days < 0 ? ' (data final anterior)' : ''}\n'
          '${parts.join(', ')}',
        ),
      ],
    );
  }

  Widget _buildDateField(
      String label, DateTime value, ValueChanged<DateTime> onPicked) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: AppTheme.caption),
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickDate(value, onPicked),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_formatDate(value)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.darkBrown,
              side: BorderSide(
                  color: AppTheme.mediumBrown.withValues(alpha: 0.3)),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
            color: AppTheme.primaryOrange.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: AppTheme.valueBold.copyWith(height: 1.4),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
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
