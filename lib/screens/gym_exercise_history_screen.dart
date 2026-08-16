import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise_log.dart';
import '../models/gym_entry.dart';
import '../utils/dates.dart';
import '../widgets/exercise_thumb.dart';

/// Everything logged for one exercise: headline numbers, weight and rep
/// progression over the last N days, and a month calendar of the days it
/// was trained. Read-only - editing happens on the day screen.
class GymExerciseHistoryScreen extends StatefulWidget {
  final ExerciseLog log;

  const GymExerciseHistoryScreen({super.key, required this.log});

  @override
  State<GymExerciseHistoryScreen> createState() =>
      _GymExerciseHistoryScreenState();
}

/// Chart windows offered by the range chips; null means "all time".
const _kRanges = <String, int?>{
  '30 dias': 30,
  '90 dias': 90,
  '1 ano': 365,
  'Tudo': null,
};

class _GymExerciseHistoryScreenState
    extends State<GymExerciseHistoryScreen> {
  int? _rangeDays = 90;

  /// Rebuilt only when the range changes, never inside build: the charts
  /// keep their own selection and reset it whenever the list identity
  /// changes, so handing them a fresh list every rebuild would wipe the
  /// selected point on every unrelated setState.
  late List<_Sample> _weightSamples;
  late List<_Sample> _repsSamples;

  /// Calendar state. Opens on the month of the last session rather than
  /// today, so an exercise not trained recently isn't a blank grid.
  late DateTime _month;
  DateTime? _selectedDay;

  late final Map<DateTime, GymEntry> _byDay;
  late final double _maxVolume;

  ExerciseLog get _log => widget.log;

  @override
  void initState() {
    super.initState();
    _byDay = {
      for (final entry in _log.entries)
        DateTime.parse(entry.entryDate): entry,
    };
    _maxVolume = _log.bestVolume;
    final last = _log.lastDate;
    _month = DateTime(last.year, last.month);
    _selectedDay = last;
    _buildSamples();
  }

  void _buildSamples() {
    final cutoff = _rangeDays == null
        ? null
        : today().subtract(Duration(days: _rangeDays!));

    // Oldest first: the charts read left to right.
    final inRange = _log.entries.reversed.where((entry) {
      if (cutoff == null) return true;
      return !DateTime.parse(entry.entryDate).isBefore(cutoff);
    }).toList();

    _weightSamples = [
      for (final entry in inRange)
        if (entry.weight != null && entry.weight! > 0)
          _Sample(
            DateTime.parse(entry.entryDate),
            entry.weight!,
            '${formatWeight(entry.weight!)} kg · ${entry.setsLabel}',
          ),
    ];
    _repsSamples = [
      for (final entry in inRange)
        _Sample(
          DateTime.parse(entry.entryDate),
          entry.reps.toDouble(),
          '${entry.setsLabel} · ${entry.sets * entry.reps} reps no total',
        ),
    ];
  }

  void _setRange(int? days) {
    setState(() {
      _rangeDays = days;
      _buildSamples();
    });
  }

  void _changeMonth(int delta) {
    setState(() =>
        _month = DateTime(_month.year, _month.month + delta));
  }

  bool get _isAtCurrentMonth {
    final now = today();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _log.exercise;

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: Text(exercise.namePt ?? exercise.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            _buildRangeChips(),
            const SizedBox(height: 12),
            _SeriesChart(
              title: 'Peso (kg)',
              samples: _weightSamples,
              emptyLabel: _log.weighted.isEmpty
                  ? 'Exercício sem peso registrado.'
                  : 'Nenhuma sessão com peso neste período.',
              asBars: false,
            ),
            const SizedBox(height: 20),
            _SeriesChart(
              title: 'Repetições por série',
              samples: _repsSamples,
              emptyLabel: 'Nenhuma sessão neste período.',
              asBars: true,
            ),
            const SizedBox(height: 20),
            _buildCalendarCard(),
          ],
        ),
      ),
    );
  }

  // --- Header ---

  Widget _buildHeaderCard() {
    final exercise = _log.exercise;
    final pr = _log.prEntry;
    final oneRepMax = _log.bestOneRepMax;
    final progress = _log.weightProgress;

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
          Row(
            children: [
              ExerciseThumb(exercise: exercise, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name,
                        style: AppTheme.valueBold,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (exercise.muscleGroup != null) ...[
                      const SizedBox(height: 2),
                      Text(exercise.muscleGroup!,
                          style: AppTheme.caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStat('Recorde',
                    pr == null ? '—' : '${formatWeight(pr.weight!)} kg'),
              ),
              Expanded(child: _buildStat('Sessões', '${_log.sessions}')),
              Expanded(
                child: _buildStat(
                  'Evolução',
                  progress == null
                      ? '—'
                      : '${progress >= 0 ? '+' : '−'}'
                          '${formatWeight(progress.abs())} kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStat(
                    'Volume total', formatVolume(_log.totalVolume)),
              ),
              Expanded(
                child: _buildStat(
                    'Melhor sessão', formatVolume(_log.bestVolume)),
              ),
              Expanded(
                child: _buildStat('Última vez', _daysAgoLabel(_log.lastDate)),
              ),
            ],
          ),
          if (pr != null) ...[
            const SizedBox(height: 14),
            Text(
              'Recorde em ${formatDayMonth(DateTime.parse(pr.entryDate))} '
              '(${pr.setsLabel})'
              '${oneRepMax == null ? '' : ' · 1RM estimado '
                  '${formatWeight(_roundHalf(oneRepMax))} kg'}',
              style:
                  AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
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
        Text(value,
            style: AppTheme.headingMedium.copyWith(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildRangeChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final range in _kRanges.entries)
            _buildChip(range.key, range.value),
        ],
      ),
    );
  }

  Widget _buildChip(String label, int? days) {
    final selected = _rangeDays == days;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: selected ? null : AppTheme.softShadow,
        ),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => _setRange(days),
          selectedColor: AppTheme.primaryOrange,
          backgroundColor: AppTheme.white,
          checkmarkColor: AppTheme.white,
          elevation: 0,
          pressElevation: 0,
          shadowColor: Colors.transparent,
          labelStyle: TextStyle(
            color: selected ? AppTheme.white : AppTheme.mediumBrown,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
        ),
      ),
    );
  }

  // --- Calendar ---

  Widget _buildCalendarCard() {
    final monthSessions = _byDay.keys
        .where((d) => d.year == _month.year && d.month == _month.month)
        .length;
    final selected = _selectedDay;
    final selectedEntry = selected == null ? null : _byDay[selected];

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
          const Text('Dias treinados', style: AppTheme.sectionTitle),
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Mês anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(formatMonthYear(_month),
                      style: AppTheme.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                onPressed:
                    _isAtCurrentMonth ? null : () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Próximo mês',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ExerciseCalendar(
            month: _month,
            byDay: _byDay,
            maxVolume: _maxVolume,
            selected: _selectedDay,
            onDayTap: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: 14),
          const _CalendarLegend(),
          const SizedBox(height: 10),
          Text(
            monthSessions == 0
                ? 'Nenhum treino em ${formatMonthYear(_month).toLowerCase()}.'
                : '$monthSessions '
                    '${monthSessions == 1 ? 'treino' : 'treinos'} '
                    'em ${formatMonthYear(_month).toLowerCase()}.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
          if (selectedEntry != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                formatDayMonth(selected!),
                selectedEntry.setsLabel,
                if (selectedEntry.weight != null &&
                    selectedEntry.weight! > 0)
                  '${formatWeight(selectedEntry.weight!)} kg',
                if (selectedEntry.notes != null &&
                    selectedEntry.notes!.isNotEmpty)
                  selectedEntry.notes!,
              ].join(' · '),
              style: AppTheme.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// "hoje", "ontem", "há 5 dias", or the date once that stops being
/// readable at a glance.
String _daysAgoLabel(DateTime day) {
  final days = today().difference(day).inDays;
  if (days <= 0) return 'hoje';
  if (days == 1) return 'ontem';
  if (days < 30) return 'há $days dias';
  return formatDayMonth(day);
}

/// Volumes run into the tens of thousands of kilos, which is unreadable
/// as a raw number; past a tonne it switches unit.
String formatVolume(double kg) {
  if (kg <= 0) return '—';
  if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)} t';
  return '${kg.round()} kg';
}

double _roundHalf(double v) => (v * 2).round() / 2;

// ---------------------------------------------------------------------------
// Charts
// ---------------------------------------------------------------------------

/// One plotted session.
class _Sample {
  final DateTime date;
  final double value;

  /// Shown above the chart while this point is selected.
  final String label;

  const _Sample(this.date, this.value, this.label);
}

/// A card holding one time series, drawn either as a line (weight, where
/// the trend is the point) or as bars (reps, which are counts). Tap or
/// drag across it to inspect a session.
class _SeriesChart extends StatefulWidget {
  final String title;
  final List<_Sample> samples;
  final String emptyLabel;
  final bool asBars;

  const _SeriesChart({
    required this.title,
    required this.samples,
    required this.emptyLabel,
    required this.asBars,
  });

  @override
  State<_SeriesChart> createState() => _SeriesChartState();
}

class _SeriesChartState extends State<_SeriesChart> {
  int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.samples.isEmpty ? null : widget.samples.length - 1;
  }

  @override
  void didUpdateWidget(_SeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent only rebuilds the sample list when the range changes, so
    // an identity change means the data really is different.
    if (!identical(oldWidget.samples, widget.samples)) {
      _selected =
          widget.samples.isEmpty ? null : widget.samples.length - 1;
    }
  }

  void _selectAt(double dx, double width) {
    final samples = widget.samples;
    if (samples.isEmpty) return;
    final plotWidth = width - _SeriesPainter.leftLabelWidth;
    if (plotWidth <= 0) return;

    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < samples.length; i++) {
      final distance =
          (_SeriesPainter.xOf(i, samples, plotWidth) - dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    if (best != _selected) setState(() => _selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final samples = widget.samples;
    final selected =
        _selected != null && _selected! < samples.length
            ? samples[_selected!]
            : null;

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
          Text(widget.title, style: AppTheme.sectionTitle),
          const SizedBox(height: 4),
          Text(
            selected == null
                ? widget.emptyLabel
                : '${formatDayMonth(selected.date)} · ${selected.label}',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (samples.isEmpty)
            const SizedBox(height: 8)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (d) => _selectAt(
                      d.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragUpdate: (d) => _selectAt(
                      d.localPosition.dx, constraints.maxWidth),
                  child: SizedBox(
                    height: 180,
                    width: constraints.maxWidth,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _SeriesPainter(
                        samples: samples,
                        selectedIndex: _selected,
                        asBars: widget.asBars,
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

class _SeriesPainter extends CustomPainter {
  final List<_Sample> samples;
  final int? selectedIndex;
  final bool asBars;

  _SeriesPainter({
    required this.samples,
    required this.selectedIndex,
    required this.asBars,
  });

  static const leftLabelWidth = 34.0;
  static const _bottomAxisHeight = 18.0;

  /// Keeps the first and last markers off the axis edges.
  static const _edgeInset = 10.0;

  /// Horizontal position of sample [i], spaced by date rather than by
  /// index so a three-month gap in training actually looks like one.
  /// Shared with the hit test so taps land on what they look like.
  static double xOf(int i, List<_Sample> samples, double plotWidth) {
    final inner = plotWidth - _edgeInset * 2;
    if (samples.length == 1) return leftLabelWidth + plotWidth / 2;

    final start = samples.first.date.millisecondsSinceEpoch;
    final span =
        (samples.last.date.millisecondsSinceEpoch - start).toDouble();
    final t = span <= 0
        ? i / (samples.length - 1)
        : (samples[i].date.millisecondsSinceEpoch - start) / span;
    return leftLabelWidth + _edgeInset + t * inner;
  }

  /// Round number at or above [v], so the y axis lands on readable steps.
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
    final plotWidth = size.width - leftLabelWidth;
    final plotBottom = size.height - _bottomAxisHeight;
    if (plotWidth <= 0 || plotBottom <= 0 || samples.isEmpty) return;

    final maxValue =
        samples.fold<double>(0, (m, s) => s.value > m ? s.value : m);
    final axisMax = _niceMax(maxValue);

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      fontSize: 10,
      color: AppTheme.mediumBrown.withValues(alpha: 0.7),
    );

    double yOf(double value) =>
        plotBottom - plotBottom * (value / axisMax).clamp(0.0, 1.0);

    // Four bands: enough to read a value off without crowding the plot.
    for (var i = 0; i <= 4; i++) {
      final value = axisMax * i / 4;
      final y = yOf(value);
      canvas.drawLine(
          Offset(leftLabelWidth, y), Offset(size.width, y), gridPaint);
      if (i > 0) {
        _paintText(canvas, _axisLabel(value),
            Offset(leftLabelWidth - 6, y),
            anchorRight: true, style: labelStyle);
      }
    }

    if (asBars) {
      _paintBars(canvas, plotWidth, plotBottom, yOf);
    } else {
      _paintLine(canvas, plotWidth, plotBottom, yOf);
    }

    // Selection guide, drawn over the series.
    final selected = selectedIndex;
    if (selected != null && selected < samples.length) {
      final x = xOf(selected, samples, plotWidth);
      final y = yOf(samples[selected].value);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, plotBottom),
        Paint()
          ..color = AppTheme.darkBrown.withValues(alpha: 0.25)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = AppTheme.white);
      canvas.drawCircle(
          Offset(x, y), 4.5, Paint()..color = AppTheme.darkBrown);
    }

    // Baseline plus the dates at either end of the window.
    canvas.drawLine(Offset(leftLabelWidth, plotBottom),
        Offset(size.width, plotBottom), gridPaint);
    _paintText(
      canvas,
      formatDayMonth(samples.first.date),
      Offset(leftLabelWidth, plotBottom + _bottomAxisHeight / 2),
      style: labelStyle,
    );
    if (samples.length > 1) {
      _paintText(
        canvas,
        formatDayMonth(samples.last.date),
        Offset(size.width, plotBottom + _bottomAxisHeight / 2),
        anchorRight: true,
        style: labelStyle,
      );
    }
  }

  void _paintBars(Canvas canvas, double plotWidth, double plotBottom,
      double Function(double) yOf) {
    final barWidth =
        (plotWidth / (samples.length * 1.6)).clamp(2.0, 16.0);
    final radius = Radius.circular((barWidth / 2).clamp(1.0, 4.0));

    for (var i = 0; i < samples.length; i++) {
      final x = xOf(i, samples, plotWidth);
      final top = yOf(samples[i].value);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
              x - barWidth / 2, top, x + barWidth / 2, plotBottom),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()
          ..color = i == selectedIndex
              ? AppTheme.darkBrown
              : AppTheme.primaryOrange,
      );
    }
  }

  void _paintLine(Canvas canvas, double plotWidth, double plotBottom,
      double Function(double) yOf) {
    final points = [
      for (var i = 0; i < samples.length; i++)
        Offset(xOf(i, samples, plotWidth), yOf(samples[i].value)),
    ];

    // Soft wash under the line so the trend reads even on a busy grid.
    if (points.length > 1) {
      final fill = Path()..moveTo(points.first.dx, plotBottom);
      for (final point in points) {
        fill.lineTo(point.dx, point.dy);
      }
      fill
        ..lineTo(points.last.dx, plotBottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..color = AppTheme.primaryOrange.withValues(alpha: 0.12),
      );

      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppTheme.primaryOrange,
      );
    }

    // Markers stay small on long windows so they don't merge into a blob.
    final dotRadius = points.length > 40 ? 2.0 : 3.5;
    for (final point in points) {
      canvas.drawCircle(
          point, dotRadius, Paint()..color = AppTheme.primaryOrange);
    }
  }

  String _axisLabel(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

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
    if (anchorRight) offset = offset.translate(-painter.width, 0);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_SeriesPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.asBars != asBars;
  }
}

// ---------------------------------------------------------------------------
// Calendar
// ---------------------------------------------------------------------------

int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

/// Month grid of the days this exercise was trained, laid out like the
/// habit calendar. Untouched days stay neutral; a trained day is shaded
/// by how much was lifted relative to the best session ever, so a heavy
/// month is visible at a glance.
class _ExerciseCalendar extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, GymEntry> byDay;
  final double maxVolume;
  final DateTime? selected;
  final ValueChanged<DateTime> onDayTap;

  const _ExerciseCalendar({
    required this.month,
    required this.byDay,
    required this.maxVolume,
    required this.selected,
    required this.onDayTap,
  });

  static const headerHeight = 20.0;
  static const cellSpacing = 4.0;

  static double cellSize(double width) => (width - cellSpacing * 6) / 7;

  /// Monday-first, like the rest of the app's date labels.
  static int leadingBlanks(DateTime month) =>
      DateTime(month.year, month.month, 1).weekday - 1;

  static int rowsFor(DateTime month) =>
      ((leadingBlanks(month) + _daysInMonth(month)) / 7).ceil();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cell = cellSize(width);
        final rows = rowsFor(month);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleTap(details.localPosition, cell),
          child: CustomPaint(
            size: Size(
                width, headerHeight + rows * (cell + cellSpacing)),
            painter: _ExerciseCalendarPainter(
              month: month,
              byDay: byDay,
              maxVolume: maxVolume,
              selected: selected,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset position, double cell) {
    if (position.dy < headerHeight) return;
    final step = cell + cellSpacing;
    final col = (position.dx / step).floor();
    final row = ((position.dy - headerHeight) / step).floor();
    if (col < 0 || col > 6 || row < 0) return;

    final dayNumber = row * 7 + col - leadingBlanks(month) + 1;
    if (dayNumber < 1 || dayNumber > _daysInMonth(month)) return;
    onDayTap(DateTime(month.year, month.month, dayNumber));
  }
}

/// The three swatches explaining the shading, for use under the calendar.
class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color color) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        );

    return Row(
      children: [
        Text('Sem treino', style: AppTheme.caption),
        const SizedBox(width: 6),
        swatch(_ExerciseCalendarPainter.shadeFor(0)),
        const SizedBox(width: 4),
        swatch(_ExerciseCalendarPainter.shadeFor(0.35)),
        const SizedBox(width: 4),
        swatch(_ExerciseCalendarPainter.shadeFor(0.7)),
        const SizedBox(width: 4),
        swatch(_ExerciseCalendarPainter.shadeFor(1)),
        const SizedBox(width: 6),
        Text('Mais volume', style: AppTheme.caption),
      ],
    );
  }
}

class _ExerciseCalendarPainter extends CustomPainter {
  final DateTime month;
  final Map<DateTime, GymEntry> byDay;
  final double maxVolume;
  final DateTime? selected;

  _ExerciseCalendarPainter({
    required this.month,
    required this.byDay,
    required this.maxVolume,
    required this.selected,
  });

  static const _weekdaysShort = [
    'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom',
  ];

  static const _emptyFill = Color(0x66FFE4D6); // lightPeach, faded
  static const _rampStart = AppTheme.lightOrange;
  static const _rampEnd = AppTheme.mediumBrown;

  /// Fill for a day at [fraction] of the heaviest session on record.
  /// Bodyweight work has no volume at all, so trained days never fall
  /// below a visible minimum - see the floor applied in [paint].
  static Color shadeFor(double fraction) {
    if (fraction <= 0) return _emptyFill;
    return Color.lerp(_rampStart, _rampEnd, fraction.clamp(0.0, 1.0))!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = _ExerciseCalendar.cellSize(size.width);
    final step = cell + _ExerciseCalendar.cellSpacing;
    final leading = _ExerciseCalendar.leadingBlanks(month);
    final total = _daysInMonth(month);
    final todayDate = today();

    for (var col = 0; col < 7; col++) {
      _paintText(
        canvas,
        _weekdaysShort[col],
        Offset(col * step + cell / 2,
            _ExerciseCalendar.headerHeight / 2),
        anchorCenter: true,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.mediumBrown.withValues(alpha: 0.7),
        ),
      );
    }

    final fillPaint = Paint();

    for (var dayNumber = 1; dayNumber <= total; dayNumber++) {
      final index = leading + dayNumber - 1;
      final left = (index % 7) * step;
      final top =
          _ExerciseCalendar.headerHeight + (index ~/ 7) * step;
      final rect = Rect.fromLTWH(left, top, cell, cell);
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22));

      final day = DateTime(month.year, month.month, dayNumber);
      final entry = byDay[day];

      // A trained day always reads as trained, even at zero volume.
      final fraction = entry == null
          ? 0.0
          : maxVolume > 0
              ? math.max(0.3, entry.volume / maxVolume)
              : 1.0;

      fillPaint.color = shadeFor(fraction);
      canvas.drawRRect(rrect, fillPaint);

      if (day == selected) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = AppTheme.darkBrown,
        );
      } else if (day == todayDate) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppTheme.mediumBrown.withValues(alpha: 0.5),
        );
      }

      _paintText(
        canvas,
        '$dayNumber',
        rect.center,
        anchorCenter: true,
        style: TextStyle(
          fontSize: (cell * 0.34).clamp(9.0, 13.0),
          fontWeight: FontWeight.w600,
          // Dark fills need light text; empty cells stay brown.
          color: fraction >= 0.45
              ? Colors.white
              : AppTheme.mediumBrown.withValues(alpha: 0.9),
        ),
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required TextStyle style,
    bool anchorCenter = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var offset = Offset(position.dx, position.dy - painter.height / 2);
    if (anchorCenter) offset = offset.translate(-painter.width / 2, 0);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ExerciseCalendarPainter oldDelegate) {
    return oldDelegate.month != month ||
        oldDelegate.byDay != byDay ||
        oldDelegate.maxVolume != maxVolume ||
        oldDelegate.selected != selected;
  }
}
