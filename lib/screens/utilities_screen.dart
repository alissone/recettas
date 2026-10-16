import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/utility_reading.dart';
import '../services/supabase_service.dart';
import '../services/utility_usage.dart';
import '../utils/brl.dart';
import '../utils/dates.dart';

/// Water and electricity: log what the meter shows, and see the month's
/// usage, cost and forecast. Usage is never typed in - it is the
/// difference between consecutive readings, with the first reading of
/// each meter serving only as the starting point.
class UtilitiesScreen extends StatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

/// 12,5 -> "12,5"; pt-BR decimal comma.
String _num(double v, [int decimals = 1]) =>
    v.toStringAsFixed(decimals).replaceAll('.', ',');

class _UtilitiesScreenState extends State<UtilitiesScreen> {
  UtilityKind _kind = UtilityKind.energy;
  final Map<UtilityKind, List<UtilityReading>> _readings = {};
  Map<UtilityKind, double> _prices = {};
  bool _loading = true;
  Object? _error;

  /// Recomputed only when data changes, so the chart isn't handed a fresh
  /// object on every unrelated rebuild.
  UtilityUsage? _usage;

  List<UtilityReading> get _list => _readings[_kind] ?? const [];
  double? get _price => _prices[_kind];
  int get _decimals => _kind == UtilityKind.water ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        for (final kind in UtilityKind.values)
          SupabaseService.getUtilityReadings(kind),
        SupabaseService.getUtilityPrices(),
      ]);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < UtilityKind.values.length; i++) {
          _readings[UtilityKind.values[i]] =
              results[i] as List<UtilityReading>;
        }
        _prices = results.last as Map<UtilityKind, double>;
        _error = null;
        _loading = false;
        _recompute();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _recompute() {
    _usage = UtilityUsage.compute(_list, DateTime.now());
  }

  void _setKind(UtilityKind kind) {
    setState(() {
      _kind = kind;
      _recompute();
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Actions ---

  Future<double?> _promptNumber({
    required String title,
    required String label,
    String? hint,
    String? initial,
    String? suffix,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixText: suffix,
            filled: true,
            fillColor: AppTheme.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, parseBrlInput(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, parseBrlInput(controller.text)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addReading() async {
    final last = _list.isEmpty ? null : _list.last;
    final value = await _promptNumber(
      title: last == null
          ? 'Primeira leitura de ${_kind.label.toLowerCase()}'
          : 'Nova leitura de ${_kind.label.toLowerCase()}',
      label: 'Número no medidor',
      hint: last == null ? null : 'Última: ${_num(last.value, _decimals)}',
      suffix: _kind.unit,
    );
    if (value == null || !mounted) return;

    if (value < 0) {
      _snack('A leitura não pode ser negativa.');
      return;
    }
    if (last != null && value < last.value) {
      _snack('A leitura é menor que a última '
          '(${_num(last.value, _decimals)} ${_kind.unit}). '
          'Medidores só avançam - confira o número.');
      return;
    }
    try {
      await SupabaseService.addUtilityReading(_kind, value);
      await _load();
    } catch (e) {
      if (mounted) _snack('Falha ao registrar: $e');
    }
  }

  Future<void> _editPrice() async {
    final price = await _promptNumber(
      title: _kind == UtilityKind.water
          ? 'Preço do m³ de água'
          : 'Preço do kWh',
      label: 'Preço atual',
      initial: _price == null ? null : _num(_price!, 2),
      suffix: 'R\$ / ${_kind.unit}',
    );
    if (price == null || !mounted) return;
    try {
      await SupabaseService.saveUtilityPrice(_kind, price);
      await _load();
    } catch (e) {
      if (mounted) _snack('Falha ao salvar: $e');
    }
  }

  Future<void> _deleteReading(UtilityReading reading) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        title: const Text('Excluir leitura?'),
        content: Text('${_num(reading.value, _decimals)} ${_kind.unit} em '
            '${formatDayMonth(reading.recordedAt)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService.deleteUtilityReading(reading.id);
      await _load();
    } catch (e) {
      if (mounted) _snack('Falha ao excluir: $e');
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Água e energia')),
      floatingActionButton: SupabaseService.currentUser == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addReading,
              backgroundColor: _kind.color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nova leitura'),
            ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (SupabaseService.currentUser == null) {
      return Center(
        child: Text('Entre na sua conta para registrar leituras.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400)),
      );
    }
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Não foi possível carregar: $_error',
                  textAlign: TextAlign.center, style: AppTheme.caption),
              TextButton(onPressed: _load, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    final usage = _usage;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryOrange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bottom padding clears the floating button.
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          _buildKindChips(),
          const SizedBox(height: 16),
          if (usage == null)
            _buildEmptyState()
          else ...[
            _buildHeroCard(usage),
            const SizedBox(height: 20),
            _buildChartCard(usage),
          ],
          const SizedBox(height: 20),
          _buildPriceRow(),
          if (_list.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildReadingsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildKindChips() {
    return Row(
      children: [
        for (final kind in UtilityKind.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(kind.icon,
                  size: 18,
                  color: _kind == kind ? AppTheme.white : kind.color),
              label: Text(kind.label),
              selected: _kind == kind,
              onSelected: (_) => _setKind(kind),
              selectedColor: kind.color,
              backgroundColor: AppTheme.white,
              showCheckmark: false,
              side: BorderSide.none,
              labelStyle: TextStyle(
                color: _kind == kind ? AppTheme.white : AppTheme.mediumBrown,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildEmptyState() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comece pela primeira leitura',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Anote o número que o medidor de ${_kind.label.toLowerCase()} '
            'mostra agora. Ele vira o ponto de partida: o consumo é '
            'calculado a partir das leituras seguintes. Quanto mais '
            'leituras por semana, melhor a previsão.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  // --- Hero ---

  String? _cost(double? amount) {
    final price = _price;
    if (amount == null || price == null) return null;
    return formatBrl(amount * price);
  }

  Widget _buildHeroCard(UtilityUsage usage) {
    final unit = _kind.unit;
    final usedCost = _cost(usage.usedSoFar);
    final projectedCost = _cost(usage.projected);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Consumo em ${formatMonthYear(usage.monthStart).toLowerCase()}',
              style: AppTheme.caption),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_num(usage.usedSoFar, _decimals),
                  style: AppTheme.headingLarge.copyWith(
                      fontSize: 44, color: _kind.color)),
              const SizedBox(width: 6),
              Text(unit, style: AppTheme.sectionTitle),
            ],
          ),
          Text(
            usedCost == null
                ? 'Defina o preço para ver o gasto em reais'
                : '$usedCost até agora',
            style: AppTheme.valueBold,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Previsto no mês',
                  usage.projected == null
                      ? '—'
                      : '${_num(usage.projected!, _decimals)} $unit',
                  usage.projected == null
                      ? 'Precisa de mais leituras'
                      : (projectedCost ?? 'sem preço'),
                ),
              ),
              Expanded(
                child: _stat(
                  'Mês anterior (total)',
                  usage.prevTotal == null
                      ? '—'
                      : '${_num(usage.prevTotal!, _decimals)} $unit',
                  usage.prevTotal == null
                      ? 'Sem dados'
                      : (_cost(usage.prevTotal) ?? 'sem preço'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildComparison(usage),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 2),
        Text(value,
            style: AppTheme.headingMedium.copyWith(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(sub, style: AppTheme.caption),
      ],
    );
  }

  Widget _buildComparison(UtilityUsage usage) {
    final dayLabel = formatDayMonth(usage.asOf);
    final prev = usage.prevSoFar;
    if (prev == null) {
      return Text(
        'Comparação com o mês anterior disponível quando houver '
        'leituras desde antes do início dele.',
        style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
      );
    }
    final diff = usage.usedSoFar - prev;
    final change = usage.changeVsPrev;
    // Using less is the good direction for a utility bill.
    final color = diff > 0 ? const Color(0xFFC0392B) : const Color(0xFF2E8B57);
    final prevCost = _cost(prev);
    final diffCost = _cost(diff.abs());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(diff > 0 ? Icons.trending_up : Icons.trending_down,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change == null
                      ? '${diff >= 0 ? '+' : '−'}'
                          '${_num(diff.abs(), _decimals)} ${_kind.unit}'
                      : '${diff >= 0 ? '+' : '−'}'
                          '${(change.abs() * 100).round()}% '
                          '(${_num(diff.abs(), _decimals)} ${_kind.unit}'
                          '${diffCost == null ? '' : ' · $diffCost'})',
                  style: AppTheme.valueBold.copyWith(color: color),
                ),
                Text(
                  'vs. mês anterior até ${dayLabel.split('/').first}: '
                  '${_num(prev, _decimals)} ${_kind.unit}'
                  '${prevCost == null ? '' : ' · $prevCost'}',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Chart ---

  Widget _buildChartCard(UtilityUsage usage) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Consumo acumulado (${_kind.unit})',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _UsagePainter(usage: usage, color: _kind.color),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(_kind.color, 'Este mês', dashed: false),
              _legend(_kind.color, 'Previsão', dashed: true),
              _legend(AppTheme.mediumBrown.withValues(alpha: 0.4),
                  'Mês anterior',
                  dashed: false),
            ],
          ),
          if (usage.projected != null) ...[
            const SizedBox(height: 8),
            Text(
              'Previsão: ritmo médio das leituras do mês aplicado aos dias '
              'restantes (regressão linear).',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, {required bool dashed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 4,
          child: CustomPaint(
              painter: _SwatchPainter(color: color, dashed: dashed)),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTheme.caption),
      ],
    );
  }

  // --- Price + readings ---

  Widget _buildPriceRow() {
    final price = _price;
    return _card(
      child: Row(
        children: [
          Icon(_kind.icon, color: _kind.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _kind == UtilityKind.water
                        ? 'Preço do m³'
                        : 'Preço do kWh',
                    style: AppTheme.caption),
                Text(
                  price == null ? 'Não definido' : formatBrl(price),
                  style: AppTheme.valueBold,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _editPrice,
            child: Text(price == null ? 'Definir' : 'Alterar'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingsCard() {
    // Newest first, each with the usage since the reading before it.
    final list = _list;
    final shown = list.reversed.take(15).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Leituras', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          for (final reading in shown)
            Builder(builder: (context) {
              final index = list.indexOf(reading);
              final delta =
                  index == 0 ? null : reading.value - list[index - 1].value;
              final t = reading.recordedAt;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                    '${_num(reading.value, _decimals)} ${_kind.unit}',
                    style: AppTheme.valueBold),
                subtitle: Text(
                  '${formatDayMonth(t)} '
                  '${t.hour.toString().padLeft(2, '0')}:'
                  '${t.minute.toString().padLeft(2, '0')}'
                  ' · ${delta == null ? 'ponto de partida' : '+${_num(delta, _decimals)} ${_kind.unit}'}',
                  style: AppTheme.caption,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.mediumBrown),
                  tooltip: 'Excluir',
                  onPressed: () => _deleteReading(reading),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart painting
// ---------------------------------------------------------------------------

class _SwatchPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _SwatchPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), paint);
      return;
    }
    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width * 0.4, size.height / 2), paint);
    canvas.drawLine(Offset(size.width * 0.65, size.height / 2),
        Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.color != color || old.dashed != dashed;
}

/// Cumulative usage across the month: this month solid, the forecast to
/// month end dashed, and last month as a faint reference line.
class _UsagePainter extends CustomPainter {
  final UtilityUsage usage;
  final Color color;

  _UsagePainter({required this.usage, required this.color});

  static const _leftLabelWidth = 38.0;
  static const _bottomAxisHeight = 18.0;
  static const _edgeInset = 6.0;

  static double _niceMax(double v) {
    if (v <= 0) return 1;
    final magnitude =
        math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final step in [1.0, 1.5, 2.0, 2.5, 5.0]) {
      if (v <= magnitude * step) return magnitude * step;
    }
    return magnitude * 10;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _leftLabelWidth;
    final plotBottom = size.height - _bottomAxisHeight;
    if (plotWidth <= 0 || plotBottom <= 0) return;

    final days = usage.daysInMonth.toDouble();
    var maxY = 0.0;
    for (final series in [usage.current, usage.previous, usage.forecast]) {
      for (final p in series) {
        if (p.y > maxY) maxY = p.y;
      }
    }
    final axisMax = _niceMax(maxY);

    final inner = plotWidth - _edgeInset * 2;
    double xOf(double x) =>
        _leftLabelWidth + _edgeInset + (x / days).clamp(0.0, 1.0) * inner;
    double yOf(double y) =>
        plotBottom - plotBottom * (y / axisMax).clamp(0.0, 1.0);

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      fontSize: 10,
      color: AppTheme.mediumBrown.withValues(alpha: 0.7),
    );

    for (var i = 0; i <= 4; i++) {
      final value = axisMax * i / 4;
      final y = yOf(value);
      canvas.drawLine(
          Offset(_leftLabelWidth, y), Offset(size.width, y), gridPaint);
      if (i > 0) {
        _paintText(
            canvas,
            value == value.roundToDouble()
                ? value.round().toString()
                : _num(value),
            Offset(_leftLabelWidth - 6, y),
            style: labelStyle,
            anchorRight: true);
      }
    }

    // Day ticks every week, plus the last day.
    for (var d = 0; d < usage.daysInMonth; d += 7) {
      _paintText(canvas, '${d + 1}',
          Offset(xOf(d.toDouble()), plotBottom + _bottomAxisHeight / 2),
          style: labelStyle, anchorCenter: true);
    }

    Path pathOf(List<UsagePoint> pts) {
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = Offset(xOf(pts[i].x), yOf(pts[i].y));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      return path;
    }

    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    if (usage.previous.length > 1) {
      canvas.drawPath(pathOf(usage.previous),
          stroke(AppTheme.mediumBrown.withValues(alpha: 0.4), 2));
    }

    if (usage.forecast.length > 1) {
      final forecastPaint = stroke(color.withValues(alpha: 0.7), 2.5);
      for (final PathMetric metric
          in pathOf(usage.forecast).computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          canvas.drawPath(
              metric.extractPath(distance, distance + 7), forecastPaint);
          distance += 12;
        }
      }
    }

    if (usage.current.length > 1) {
      canvas.drawPath(pathOf(usage.current), stroke(color, 3));
    }
    for (final p in usage.current) {
      canvas.drawCircle(
          Offset(xOf(p.x), yOf(p.y)), 3.5, Paint()..color = color);
    }

    canvas.drawLine(Offset(_leftLabelWidth, plotBottom),
        Offset(size.width, plotBottom), gridPaint);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required TextStyle style,
    bool anchorRight = false,
    bool anchorCenter = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var offset = Offset(position.dx, position.dy - painter.height / 2);
    if (anchorRight) offset = offset.translate(-painter.width, 0);
    if (anchorCenter) offset = offset.translate(-painter.width / 2, 0);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_UsagePainter old) =>
      old.usage != usage || old.color != color;
}
