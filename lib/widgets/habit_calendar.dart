import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/habit.dart';

/// Month grid showing how much of a habit was done each day. Untouched
/// days stay neutral; from there the fill runs pink -> deep red as the
/// day fills up, and a day that reaches its target gets a green check
/// drawn on top.
///
/// For weekly and monthly habits the target is spread evenly across the
/// days of the period, so a single day can still be shaded; the true
/// period progress is shown separately by the screen.
class HabitCalendar extends StatelessWidget {
  /// Any day inside the month to draw.
  final DateTime month;
  final Habit habit;

  /// Day (midnight-normalized) -> total logged that day.
  final Map<DateTime, double> totals;
  final ValueChanged<DateTime>? onDayTap;

  const HabitCalendar({
    super.key,
    required this.month,
    required this.habit,
    required this.totals,
    this.onDayTap,
  });

  static const headerHeight = 20.0;
  static const cellSpacing = 4.0;

  static double cellSize(double width) =>
      (width - cellSpacing * 6) / 7;

  static double heightFor(double width, int rows) =>
      headerHeight + rows * (cellSize(width) + cellSpacing);

  /// Blank leading cells before the 1st: Monday-first, like the rest of
  /// the app's date labels.
  static int leadingBlanks(DateTime month) =>
      DateTime(month.year, month.month, 1).weekday - 1;

  static int rowsFor(DateTime month) =>
      ((leadingBlanks(month) + daysInMonth(month)) / 7).ceil();

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(month);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cell = cellSize(width);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onDayTap == null
              ? null
              : (details) => _handleTap(details.localPosition, cell),
          child: CustomPaint(
            size: Size(width, heightFor(width, rows)),
            painter: _HabitCalendarPainter(
              month: month,
              habit: habit,
              totals: totals,
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
    if (dayNumber < 1 || dayNumber > daysInMonth(month)) return;

    final day = DateTime(month.year, month.month, dayNumber);
    final now = DateTime.now();
    if (day.isAfter(DateTime(now.year, now.month, now.day))) return;

    onDayTap!(day);
  }
}

/// The five swatches explaining the shading, for use under a calendar.
class HabitCalendarLegend extends StatelessWidget {
  const HabitCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color color, {bool checked = false}) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
        child: checked
            ? const Icon(Icons.check,
                size: 13, color: Color(0xFF2E7D32))
            : null,
      );
    }

    return Row(
      children: [
        Text('Menos', style: AppTheme.caption),
        const SizedBox(width: 6),
        swatch(_HabitCalendarPainter.shadeFor(0)),
        const SizedBox(width: 4),
        swatch(_HabitCalendarPainter.shadeFor(0.25)),
        const SizedBox(width: 4),
        swatch(_HabitCalendarPainter.shadeFor(0.6)),
        const SizedBox(width: 4),
        swatch(_HabitCalendarPainter.shadeFor(0.9)),
        const SizedBox(width: 4),
        swatch(_HabitCalendarPainter.shadeFor(1), checked: true),
        const SizedBox(width: 6),
        Text('Completo', style: AppTheme.caption),
      ],
    );
  }
}

class _HabitCalendarPainter extends CustomPainter {
  final DateTime month;
  final Habit habit;
  final Map<DateTime, double> totals;

  _HabitCalendarPainter({
    required this.month,
    required this.habit,
    required this.totals,
  });

  static const _weekdaysShort = [
    'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom',
  ];

  static const _emptyFill = Color(0x66FFE4D6); // lightPeach, faded
  static const _rampStart = Color(0xFFF8BBD0); // pink
  static const _rampEnd = Color(0xFFC62828); // deep red
  static const _checkGreen = Color(0xFF2E7D32);

  /// Fill for a day at [fraction] of its target.
  static Color shadeFor(double fraction) {
    if (fraction <= 0) return _emptyFill;
    return Color.lerp(_rampStart, _rampEnd, fraction.clamp(0.0, 1.0))!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = HabitCalendar.cellSize(size.width);
    final step = cell + HabitCalendar.cellSpacing;
    final leading = HabitCalendar.leadingBlanks(month);
    final total = daysInMonth(month);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Weekday header.
    for (var col = 0; col < 7; col++) {
      _paintText(
        canvas,
        _weekdaysShort[col],
        Offset(col * step + cell / 2, HabitCalendar.headerHeight / 2),
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
      final col = index % 7;
      final row = index ~/ 7;
      final left = col * step;
      final top = HabitCalendar.headerHeight + row * step;
      final rect = Rect.fromLTWH(left, top, cell, cell);
      final rrect = RRect.fromRectAndRadius(
          rect, Radius.circular(cell * 0.22));

      final day = DateTime(month.year, month.month, dayNumber);
      final isFuture = day.isAfter(today);
      final value = totals[day] ?? 0;
      final target = habit.dailyTarget(day);
      final fraction = target > 0 ? value / target : 0.0;
      final isComplete = !isFuture && fraction >= 1;

      fillPaint.color = isFuture ? _emptyFill : shadeFor(fraction);
      canvas.drawRRect(rrect, fillPaint);

      if (day == today) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppTheme.darkBrown,
        );
      }

      // Dark fills need light text; empty and future cells stay brown.
      final labelColor = fraction >= 0.45 && !isFuture
          ? Colors.white
          : AppTheme.mediumBrown
              .withValues(alpha: isFuture ? 0.25 : 0.9);

      if (isComplete) {
        // Move the number out of the way of the check.
        _paintText(
          canvas,
          '$dayNumber',
          Offset(left + cell * 0.2, top + cell * 0.22),
          anchorCenter: true,
          style: TextStyle(
            fontSize: (cell * 0.24).clamp(8.0, 11.0),
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        );
        _paintCheck(canvas, rect);
      } else {
        _paintText(
          canvas,
          '$dayNumber',
          rect.center,
          anchorCenter: true,
          style: TextStyle(
            fontSize: (cell * 0.34).clamp(9.0, 13.0),
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        );
      }
    }
  }

  /// Check mark as a path rather than an icon glyph, so the painter has
  /// no font dependency. A white underlay keeps it readable on both the
  /// pale start and the deep red end of the ramp.
  void _paintCheck(Canvas canvas, Rect cell) {
    final s = cell.width;
    final path = Path()
      ..moveTo(cell.left + s * 0.28, cell.top + s * 0.54)
      ..lineTo(cell.left + s * 0.45, cell.top + s * 0.70)
      ..lineTo(cell.left + s * 0.76, cell.top + s * 0.34);

    final stroke = (s * 0.11).clamp(2.0, 3.5);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _checkGreen,
    );
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
  bool shouldRepaint(_HabitCalendarPainter oldDelegate) {
    return oldDelegate.month != month ||
        oldDelegate.totals != totals ||
        oldDelegate.habit != habit;
  }
}
