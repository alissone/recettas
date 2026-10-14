import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/habit.dart' show daysInMonth;
import '../utils/dates.dart';
import 'habit_calendar.dart';

/// Month grid of the food log, for picking report days. Same layout as
/// [HabitCalendar]: a day with food logged is shaded peach -> orange by
/// how close its calories came to [kcalTarget], a selected day is filled
/// solid with a check, and days with nothing logged can't be tapped.
class FoodLogCalendar extends StatelessWidget {
  /// Any day inside the month to draw.
  final DateTime month;

  /// Day (midnight-normalized) -> kcal logged. A key present with 0 still
  /// counts as a logged day (foods without energy data).
  final Map<DateTime, double> kcalByDay;
  final double? kcalTarget;
  final Set<DateTime> selected;
  final ValueChanged<DateTime>? onDayTap;

  const FoodLogCalendar({
    super.key,
    required this.month,
    required this.kcalByDay,
    required this.selected,
    this.kcalTarget,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = HabitCalendar.rowsFor(month);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cell = HabitCalendar.cellSize(width);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onDayTap == null
              ? null
              : (details) => _handleTap(details.localPosition, cell),
          child: CustomPaint(
            size: Size(width, HabitCalendar.heightFor(width, rows)),
            painter: _FoodLogCalendarPainter(
              month: month,
              kcalByDay: kcalByDay,
              kcalTarget: kcalTarget,
              selected: selected,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset position, double cell) {
    if (position.dy < HabitCalendar.headerHeight) return;
    final step = cell + HabitCalendar.cellSpacing;
    final col = (position.dx / step).floor();
    final row = ((position.dy - HabitCalendar.headerHeight) / step).floor();
    if (col < 0 || col > 6 || row < 0) return;

    final dayNumber =
        row * 7 + col - HabitCalendar.leadingBlanks(month) + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth(month)) return;

    final day = DateTime(month.year, month.month, dayNumber);
    if (!kcalByDay.containsKey(day)) return;
    onDayTap!(day);
  }
}

/// Swatches explaining the shading, for use under a [FoodLogCalendar].
class FoodLogCalendarLegend extends StatelessWidget {
  const FoodLogCalendarLegend({super.key});

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
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : null,
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        swatch(_FoodLogCalendarPainter._emptyFill),
        Text('Sem registro', style: AppTheme.caption),
        const SizedBox(width: 6),
        swatch(_FoodLogCalendarPainter.shadeFor(0.2)),
        swatch(_FoodLogCalendarPainter.shadeFor(0.6)),
        swatch(_FoodLogCalendarPainter.shadeFor(1)),
        Text('kcal da meta', style: AppTheme.caption),
        const SizedBox(width: 6),
        swatch(_FoodLogCalendarPainter._selectedFill, checked: true),
        Text('No relatório', style: AppTheme.caption),
      ],
    );
  }
}

class _FoodLogCalendarPainter extends CustomPainter {
  final DateTime month;
  final Map<DateTime, double> kcalByDay;
  final double? kcalTarget;
  final Set<DateTime> selected;

  _FoodLogCalendarPainter({
    required this.month,
    required this.kcalByDay,
    required this.kcalTarget,
    required this.selected,
  });

  static const _emptyFill = Color(0x66FFE4D6); // lightPeach, faded
  static const _rampStart = Color(0xFFFFE0C7);
  static const _rampEnd = Color(0xFFFFB27A);
  static const _selectedFill = AppTheme.primaryOrange;

  /// Fill for a logged day at [fraction] of the kcal target.
  static Color shadeFor(double fraction) =>
      Color.lerp(_rampStart, _rampEnd, fraction.clamp(0.0, 1.0))!;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = HabitCalendar.cellSize(size.width);
    final step = cell + HabitCalendar.cellSpacing;
    final leading = HabitCalendar.leadingBlanks(month);
    final total = daysInMonth(month);
    final now = today();

    for (var col = 0; col < 7; col++) {
      _paintText(
        canvas,
        kWeekdaysShort[col],
        Offset(col * step + cell / 2, HabitCalendar.headerHeight / 2),
        TextStyle(
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
      final top = HabitCalendar.headerHeight + (index ~/ 7) * step;
      final rect = Rect.fromLTWH(left, top, cell, cell);
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22));

      final day = DateTime(month.year, month.month, dayNumber);
      final kcal = kcalByDay[day];
      final isLogged = kcal != null;
      final isSelected = isLogged && selected.contains(day);
      final target = kcalTarget;
      // Without a calorie target, any logged day gets the mid shade.
      final fraction =
          target != null && target > 0 ? (kcal ?? 0) / target : 0.5;

      fillPaint.color = isSelected
          ? _selectedFill
          : isLogged
              ? shadeFor(fraction)
              : _emptyFill;
      canvas.drawRRect(rrect, fillPaint);

      if (day == now) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppTheme.darkBrown,
        );
      }

      final labelColor = isSelected
          ? Colors.white
          : AppTheme.mediumBrown
              .withValues(alpha: isLogged ? 0.95 : 0.3);

      if (isSelected) {
        _paintText(
          canvas,
          '$dayNumber',
          Offset(left + cell * 0.2, top + cell * 0.22),
          TextStyle(
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
          TextStyle(
            fontSize: (cell * 0.34).clamp(9.0, 13.0),
            fontWeight: isLogged ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
          ),
        );
      }
    }
  }

  void _paintCheck(Canvas canvas, Rect cell) {
    final s = cell.width;
    final path = Path()
      ..moveTo(cell.left + s * 0.28, cell.top + s * 0.54)
      ..lineTo(cell.left + s * 0.45, cell.top + s * 0.70)
      ..lineTo(cell.left + s * 0.76, cell.top + s * 0.34);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.11).clamp(2.0, 3.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  void _paintText(
      Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas,
        center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_FoodLogCalendarPainter oldDelegate) {
    return oldDelegate.month != month ||
        oldDelegate.kcalByDay != kcalByDay ||
        oldDelegate.kcalTarget != kcalTarget ||
        oldDelegate.selected != selected;
  }
}
