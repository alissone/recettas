import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/sleep_event.dart';
import '../models/sleep_interval.dart';
import '../services/supabase_service.dart';
import 'sleep_history_screen.dart';

/// Sleep log: two buttons record "went to sleep" / "woke up" moments
/// (long-press to pick a custom time), and a chart shows one bar per
/// night on a noon-to-noon axis, one week or month at a time.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  bool _weekView = true;
  bool _isLoading = true;
  bool _isSaving = false;
  List<SleepEvent> _events = [];

  /// Last day of the visible range; today unless the user paged back.
  DateTime _anchorDay = _today();
  int _loadSeq = 0;

  static const _weekdaysShort = [
    'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom',
  ];

  int get _rangeDays => _weekView ? 7 : 30;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isAtToday => !_anchorDay.isBefore(_today());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    final seq = ++_loadSeq;
    try {
      // One day beyond the month view so a night that started before
      // the range still has its sleep event available for pairing.
      final from = _anchorDay.subtract(const Duration(days: 31));
      final to = _anchorDay.add(const Duration(days: 1));
      final events = await SupabaseService.getSleepEvents(from: from, to: to);
      if (mounted && seq == _loadSeq) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && seq == _loadSeq) setState(() => _isLoading = false);
    }
  }

  /// Moves the visible range back/forward by one week or month.
  void _page(int direction) {
    var next = _anchorDay.add(Duration(days: direction * _rangeDays));
    final today = _today();
    if (next.isAfter(today)) next = today;
    if (next == _anchorDay) return;
    setState(() => _anchorDay = next);
    _load();
  }

  Future<void> _record(String type, DateTime occurredAt) async {
    if (SupabaseService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entre na sua conta para registrar.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await SupabaseService.addSleepEvent(type, occurredAt);
      // Recording something newer than the visible range: jump back
      // to today so the new event is actually shown.
      if (occurredAt.isAfter(_anchorDay.add(const Duration(days: 1)))) {
        _anchorDay = _today();
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Long-press flow: pick a custom date and time for the event.
  Future<void> _recordCustom(String type) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    await _record(
      type,
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _deleteEvent(SleepEvent event) async {
    try {
      await SupabaseService.deleteSleepEvent(event.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  List<DateTime> _rangeDaysList() {
    return [
      for (var i = _rangeDays - 1; i >= 0; i--)
        _anchorDay.subtract(Duration(days: i)),
    ];
  }

  String _formatDayMonth(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _formatEventTime(DateTime d) {
    return '${_weekdaysShort[d.weekday - 1]} '
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Sono'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SleepHistoryScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildRecordButtons(),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Toque para registrar agora · '
                      'segure para escolher a hora',
                      style: AppTheme.caption
                          .copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildChartCard(),
                  const SizedBox(height: 20),
                  _buildEventList(),
                ],
              ),
      ),
    );
  }

  Widget _buildRecordButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildRecordButton(
            label: 'Fui dormir',
            icon: Icons.bedtime_outlined,
            color: AppTheme.darkBrown,
            type: 'sleep',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRecordButton(
            label: 'Acordei',
            icon: Icons.wb_sunny_outlined,
            color: AppTheme.primaryOrange,
            type: 'wake',
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton({
    required String label,
    required IconData icon,
    required Color color,
    required String type,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: _isSaving ? null : () => _record(type, DateTime.now()),
        onLongPress: _isSaving ? null : () => _recordCustom(type),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final days = _rangeDaysList();
    final intervals = buildSleepIntervals(_events);
    final inRange = intervals
        .where((i) =>
            !i.day.isBefore(days.first) && !i.day.isAfter(days.last))
        .toList();

    final totalMinutes = inRange.fold<int>(
        0, (sum, i) => sum + i.duration.inMinutes);
    final nights = inRange.map((i) => i.day).toSet().length;
    final avg = nights > 0
        ? Duration(minutes: totalMinutes ~/ nights)
        : Duration.zero;

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
              const Expanded(
                child: Text('Noites de sono',
                    style: AppTheme.sectionTitle),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Semana')),
                  ButtonSegment(value: false, label: Text('Mês')),
                ],
                selected: {_weekView},
                onSelectionChanged: (s) =>
                    setState(() => _weekView = s.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor:
                      AppTheme.primaryOrange.withValues(alpha: 0.15),
                  selectedForegroundColor: AppTheme.primaryOrange,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: AppTheme.borderOrange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                onPressed: () => _page(-1),
                icon: const Icon(Icons.chevron_left),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Período anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_formatDayMonth(days.first)} – '
                    '${_formatDayMonth(days.last)}',
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isAtToday ? null : () => _page(1),
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Próximo período',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildStat('Média por noite',
                  nights > 0 ? _formatDuration(avg) : '—'),
              const SizedBox(width: 24),
              _buildStat('Noites registradas', '$nights'),
            ],
          ),
          const SizedBox(height: 16),
          if (inRange.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nenhum registro no período.\n'
                  'Use os botões acima para começar.',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 22.0 +
                  days.length * (_weekView ? 34.0 : 12.0),
              child: CustomPaint(
                size: Size.infinite,
                painter: _SleepChartPainter(
                  days: days,
                  intervals: inRange,
                  weekView: _weekView,
                  weekdaysShort: _weekdaysShort,
                  formatDuration: _formatDuration,
                ),
              ),
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

  Widget _buildEventList() {
    final recent = List<SleepEvent>.of(_events)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final shown = recent.take(10).toList();

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
          const Text('Últimos registros', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum registro ainda.',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400)),
            ),
          for (final event in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    event.isSleep
                        ? Icons.bedtime_outlined
                        : Icons.wb_sunny_outlined,
                    size: 20,
                    color: event.isSleep
                        ? AppTheme.darkBrown
                        : AppTheme.primaryOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.isSleep ? 'Dormi' : 'Acordei',
                      style: AppTheme.bodyText,
                    ),
                  ),
                  Text(
                    _formatEventTime(event.occurredAt),
                    style: AppTheme.caption,
                  ),
                  IconButton(
                    onPressed: () => _deleteEvent(event),
                    icon: Icon(Icons.close,
                        size: 18,
                        color: AppTheme.mediumBrown
                            .withValues(alpha: 0.6)),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Excluir',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart painter: one row per night, noon-to-noon time axis
// ---------------------------------------------------------------------------

class _SleepChartPainter extends CustomPainter {
  final List<DateTime> days;
  final List<SleepInterval> intervals;
  final bool weekView;
  final List<String> weekdaysShort;
  final String Function(Duration) formatDuration;

  _SleepChartPainter({
    required this.days,
    required this.intervals,
    required this.weekView,
    required this.weekdaysShort,
    required this.formatDuration,
  });

  static const _axisHeight = 22.0;
  static const _leftLabelWidth = 46.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rightLabelWidth = weekView ? 44.0 : 0.0;
    final plotLeft = _leftLabelWidth;
    final plotWidth = size.width - plotLeft - rightLabelWidth;
    final plotTop = _axisHeight;
    final rowHeight = (size.height - plotTop) / days.length;

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    // Vertical gridlines + hour labels: window hours 0/6/12/18/24 map
    // to wall clock 12h, 18h, 00h, 06h, 12h.
    const hourMarks = [0, 6, 12, 18, 24];
    const hourLabels = ['12h', '18h', '00h', '06h', '12h'];
    for (var i = 0; i < hourMarks.length; i++) {
      final x = plotLeft + plotWidth * hourMarks[i] / 24.0;
      canvas.drawLine(
          Offset(x, plotTop), Offset(x, size.height), gridPaint);
      _paintText(
        canvas,
        hourLabels[i],
        Offset(x, _axisHeight / 2),
        anchorCenter: true,
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.mediumBrown.withValues(alpha: 0.7),
        ),
      );
    }

    final byDay = <DateTime, List<SleepInterval>>{};
    for (final interval in intervals) {
      byDay.putIfAbsent(interval.day, () => []).add(interval);
    }

    final barPaint = Paint()..color = AppTheme.primaryOrange;
    final barHeight =
        weekView ? rowHeight * 0.5 : (rowHeight - 3).clamp(2.0, 8.0);

    for (var row = 0; row < days.length; row++) {
      final day = days[row];
      final rowTop = plotTop + row * rowHeight;
      final rowCenter = rowTop + rowHeight / 2;

      // Row label: every day in week view; Mondays in month view.
      final showLabel =
          weekView || day.weekday == DateTime.monday;
      if (showLabel) {
        _paintText(
          canvas,
          weekView
              ? '${weekdaysShort[day.weekday - 1]} ${day.day}'
              : '${day.day.toString().padLeft(2, '0')}/'
                  '${day.month.toString().padLeft(2, '0')}',
          Offset(plotLeft - 8, rowCenter),
          anchorRight: true,
          style: TextStyle(
            fontSize: weekView ? 11 : 9,
            color: AppTheme.mediumBrown,
            fontWeight: FontWeight.w600,
          ),
        );
      }

      final dayIntervals = byDay[day];
      if (dayIntervals == null) continue;

      var totalDuration = Duration.zero;
      for (final interval in dayIntervals) {
        totalDuration += interval.duration;
        final left =
            plotLeft + plotWidth * interval.startHour / 24.0;
        final right =
            plotLeft + plotWidth * interval.endHour / 24.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              left,
              rowCenter - barHeight / 2,
              right.clamp(left + 2, plotLeft + plotWidth),
              rowCenter + barHeight / 2,
            ),
            const Radius.circular(4),
          ),
          barPaint,
        );
      }

      // Direct duration label, week view only (month is too dense).
      if (weekView) {
        _paintText(
          canvas,
          formatDuration(totalDuration),
          Offset(size.width, rowCenter),
          anchorRight: true,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.mediumBrown,
            fontWeight: FontWeight.w600,
          ),
        );
      }
    }
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
    var offset = Offset(
        position.dx, position.dy - painter.height / 2);
    if (anchorRight) {
      offset = offset.translate(-painter.width, 0);
    } else if (anchorCenter) {
      offset = offset.translate(-painter.width / 2, 0);
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_SleepChartPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.intervals != intervals ||
        oldDelegate.weekView != weekView;
  }
}
