import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/sleep_interval.dart';
import '../services/supabase_service.dart';

/// All-time sleep history: average sleep per night, one bar per month.
/// Tap or drag over the chart to inspect a month.
class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

/// Aggregate for one calendar month: sum of nightly totals / nights.
class _MonthStat {
  final int nights;
  final Duration total;

  _MonthStat(this.nights, this.total);

  Duration get avgPerNight =>
      nights > 0 ? Duration(minutes: total.inMinutes ~/ nights) : Duration.zero;
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  bool _isLoading = true;
  String? _error;

  /// Consecutive calendar months from first to last night on record.
  List<DateTime> _months = [];
  Map<DateTime, _MonthStat> _stats = {};
  int _totalNights = 0;
  Duration _overallAvg = Duration.zero;
  DateTime? _selectedMonth;

  static const _monthsShort = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Entre na sua conta para ver o histórico.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await SupabaseService.getAllSleepEvents();
      final intervals = buildSleepIntervals(events);

      // Total slept per noon-to-noon night, then bucket nights by month.
      final byNight = <DateTime, Duration>{};
      for (final interval in intervals) {
        byNight[interval.day] =
            (byNight[interval.day] ?? Duration.zero) + interval.duration;
      }
      final nightsByMonth = <DateTime, List<Duration>>{};
      for (final entry in byNight.entries) {
        final month = DateTime(entry.key.year, entry.key.month);
        nightsByMonth.putIfAbsent(month, () => []).add(entry.value);
      }

      final stats = <DateTime, _MonthStat>{};
      for (final entry in nightsByMonth.entries) {
        stats[entry.key] = _MonthStat(
          entry.value.length,
          entry.value.fold(Duration.zero, (sum, d) => sum + d),
        );
      }

      final months = <DateTime>[];
      if (stats.isNotEmpty) {
        final sorted = stats.keys.toList()..sort();
        // DateTime normalizes month 13 to January of the next year.
        for (var m = sorted.first;
            !m.isAfter(sorted.last);
            m = DateTime(m.year, m.month + 1)) {
          months.add(m);
        }
      }

      final totalMinutes = byNight.values
          .fold<int>(0, (sum, d) => sum + d.inMinutes);

      if (!mounted) return;
      setState(() {
        _months = months;
        _stats = stats;
        _totalNights = byNight.length;
        _overallAvg = byNight.isEmpty
            ? Duration.zero
            : Duration(minutes: totalMinutes ~/ byNight.length);
        _selectedMonth = stats.isEmpty
            ? null
            : (stats.keys.toList()..sort()).last;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Falha ao carregar: $e';
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _formatMonth(DateTime m) =>
      '${_monthsShort[m.month - 1]}/${m.year}';

  void _selectAt(Offset localPosition, double width) {
    if (_months.isEmpty) return;
    final plotWidth =
        width - _MonthlyChartPainter.leftLabelWidth;
    final cell = plotWidth / _months.length;
    final index =
        ((localPosition.dx - _MonthlyChartPainter.leftLabelWidth) / cell)
            .floor();
    if (index < 0 || index >= _months.length) return;
    final month = _months[index];
    if (_stats.containsKey(month) && month != _selectedMonth) {
      setState(() => _selectedMonth = month);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Histórico de sono')),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange))
            : _error != null
                ? _buildError()
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 20),
                      _buildChartCard(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _load,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStat('Média geral',
                _totalNights > 0 ? _formatDuration(_overallAvg) : '—'),
          ),
          Expanded(child: _buildStat('Noites', '$_totalNights')),
          Expanded(
            child: _buildStat(
                'Desde',
                _months.isEmpty ? '—' : _formatMonth(_months.first)),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.headingMedium),
      ],
    );
  }

  Widget _buildChartCard() {
    final selected = _selectedMonth;
    final selectedStat = selected != null ? _stats[selected] : null;

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
          const Text('Média de sono por noite',
              style: AppTheme.sectionTitle),
          const SizedBox(height: 4),
          Text(
            selectedStat == null
                ? 'Toque no gráfico para ver um mês'
                : '${_formatMonth(selected!)} · '
                    '${_formatDuration(selectedStat.avgPerNight)} por noite · '
                    '${selectedStat.nights} noites',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_months.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhum registro ainda.',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (d) =>
                      _selectAt(d.localPosition, constraints.maxWidth),
                  onHorizontalDragUpdate: (d) =>
                      _selectAt(d.localPosition, constraints.maxWidth),
                  child: SizedBox(
                    height: 200,
                    width: constraints.maxWidth,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _MonthlyChartPainter(
                        months: _months,
                        stats: _stats,
                        selectedMonth: _selectedMonth,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart painter: one bar per month, y = average sleep per night
// ---------------------------------------------------------------------------

class _MonthlyChartPainter extends CustomPainter {
  final List<DateTime> months;
  final Map<DateTime, _MonthStat> stats;
  final DateTime? selectedMonth;

  _MonthlyChartPainter({
    required this.months,
    required this.stats,
    required this.selectedMonth,
  });

  static const leftLabelWidth = 34.0;
  static const _bottomAxisHeight = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = leftLabelWidth;
    final plotWidth = size.width - plotLeft;
    final plotBottom = size.height - _bottomAxisHeight;

    // Even-hour ceiling above the tallest month, at least 8h.
    var maxAvg = 0.0;
    for (final stat in stats.values) {
      final h = stat.avgPerNight.inMinutes / 60.0;
      if (h > maxAvg) maxAvg = h;
    }
    final axisMax = ((maxAvg / 2).ceil() * 2).clamp(8, 24).toDouble();

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      fontSize: 10,
      color: AppTheme.mediumBrown.withValues(alpha: 0.7),
    );

    // Horizontal gridlines + hour labels every 2h.
    for (var h = 0; h <= axisMax; h += 2) {
      final y = plotBottom - plotBottom * h / axisMax;
      canvas.drawLine(
          Offset(plotLeft, y), Offset(size.width, y), gridPaint);
      if (h > 0) {
        _paintText(canvas, '${h}h', Offset(plotLeft - 6, y),
            anchorRight: true, style: labelStyle);
      }
    }

    final cell = plotWidth / months.length;
    final barWidth = (cell - 2).clamp(1.5, 16.0);
    final radius = Radius.circular((barWidth / 2).clamp(1.0, 4.0));

    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      final left = plotLeft + i * cell + (cell - barWidth) / 2;

      // Year labels under each January.
      if (month.month == DateTime.january) {
        canvas.drawLine(
          Offset(plotLeft + i * cell, plotBottom),
          Offset(plotLeft + i * cell, plotBottom + 4),
          gridPaint,
        );
        _paintText(
          canvas,
          '${month.year}',
          Offset(plotLeft + i * cell + 3,
              plotBottom + _bottomAxisHeight / 2),
          style: labelStyle,
        );
      }

      final stat = stats[month];
      if (stat == null) continue;

      final hours = stat.avgPerNight.inMinutes / 60.0;
      final top = plotBottom - plotBottom * (hours / axisMax).clamp(0.0, 1.0);
      final barPaint = Paint()
        ..color = month == selectedMonth
            ? AppTheme.darkBrown
            : AppTheme.primaryOrange;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(left, top, left + barWidth, plotBottom),
          topLeft: radius,
          topRight: radius,
        ),
        barPaint,
      );
    }

    // Baseline over the bars' feet.
    canvas.drawLine(Offset(plotLeft, plotBottom),
        Offset(size.width, plotBottom), gridPaint);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required TextStyle style,
    bool anchorRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var offset = Offset(position.dx, position.dy - painter.height / 2);
    if (anchorRight) {
      offset = offset.translate(-painter.width, 0);
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_MonthlyChartPainter oldDelegate) {
    return oldDelegate.months != months ||
        oldDelegate.stats != stats ||
        oldDelegate.selectedMonth != selectedMonth;
  }
}
