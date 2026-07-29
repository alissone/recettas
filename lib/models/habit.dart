import 'package:flutter/material.dart';

/// How a habit's progress is counted: repeats of something, or minutes
/// spent on it.
enum HabitGoalType { counter, duration }

/// The window the goal is measured over.
enum HabitPeriod { daily, weekly, monthly }

/// Icons offered by the habit editor. The keys are what habits.icon_name
/// stores; the values are const IconData references so Flutter's icon
/// tree shaking keeps working - an IconData built at runtime from a code
/// point renders as a blank box in release builds.
const Map<String, IconData> kHabitIcons = {
  'check_circle': Icons.check_circle,
  'water_drop': Icons.water_drop,
  'local_drink': Icons.local_drink,
  'directions_run': Icons.directions_run,
  'directions_walk': Icons.directions_walk,
  'fitness_center': Icons.fitness_center,
  'sports_gymnastics': Icons.sports_gymnastics,
  'self_improvement': Icons.self_improvement,
  'pedal_bike': Icons.pedal_bike,
  'pool': Icons.pool,
  'hiking': Icons.hiking,
  'menu_book': Icons.menu_book,
  'edit_note': Icons.edit_note,
  'school': Icons.school,
  'code': Icons.code,
  'language': Icons.language,
  'music_note': Icons.music_note,
  'brush': Icons.brush,
  'camera_alt': Icons.camera_alt,
  'bedtime': Icons.bedtime,
  'wb_sunny': Icons.wb_sunny,
  'alarm': Icons.alarm,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'egg_alt': Icons.egg_alt,
  'medication': Icons.medication,
  'favorite': Icons.favorite,
  'monitor_heart': Icons.monitor_heart,
  'psychology': Icons.psychology,
  'spa': Icons.spa,
  'shower': Icons.shower,
  'wash': Icons.wash,
  'cleaning_services': Icons.cleaning_services,
  'savings': Icons.savings,
  'attach_money': Icons.attach_money,
  'shopping_cart': Icons.shopping_cart,
  'smoke_free': Icons.smoke_free,
  'no_drinks': Icons.no_drinks,
  'do_not_disturb_on': Icons.do_not_disturb_on,
  'church': Icons.church,
  'volunteer_activism': Icons.volunteer_activism,
  'groups': Icons.groups,
  'pets': Icons.pets,
  'yard': Icons.yard,
  'work': Icons.work,
};

IconData habitIcon(String? name) =>
    kHabitIcons[name] ?? Icons.check_circle;

/// Number of days in the month [day] falls in.
int daysInMonth(DateTime day) =>
    DateTime(day.year, day.month + 1, 0).day;

/// A habit being tracked. The current value is never stored: it is the
/// sum of the matching [HabitLog] values over the period.
class Habit {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String iconName;
  final int colorValue;
  final String? imagePath;
  final HabitGoalType goalType;

  /// Repeats for counter goals, minutes for duration goals.
  final double goalTarget;

  /// Counter label ("copos", "páginas"); null means "vezes".
  final String? goalUnit;
  final HabitPeriod period;
  final bool isArchived;
  final int sortOrder;
  final DateTime? createdAt;

  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.iconName = 'check_circle',
    this.colorValue = 0xFFFF8C42,
    this.imagePath,
    this.goalType = HabitGoalType.counter,
    this.goalTarget = 1,
    this.goalUnit,
    this.period = HabitPeriod.daily,
    this.isArchived = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  Color get color => Color(colorValue);

  IconData get icon => habitIcon(iconName);

  bool get isDuration => goalType == HabitGoalType.duration;

  /// What one repeat is called. Duration goals count minutes.
  String get unitLabel {
    if (isDuration) return 'min';
    final unit = goalUnit;
    return unit == null || unit.isEmpty ? 'vezes' : unit;
  }

  String get periodLabel => switch (period) {
        HabitPeriod.daily => 'por dia',
        HabitPeriod.weekly => 'por semana',
        HabitPeriod.monthly => 'por mês',
      };

  /// "30min por dia", "8 copos por dia".
  String get goalLabel => '${formatValue(goalTarget)} $periodLabel';

  /// The share of [goalTarget] expected on a single day. Weekly and
  /// monthly goals spread evenly so the calendar can shade one day at a
  /// time; the true period progress is shown separately.
  double dailyTarget(DateTime day) => switch (period) {
        HabitPeriod.daily => goalTarget,
        HabitPeriod.weekly => goalTarget / 7,
        HabitPeriod.monthly => goalTarget / daysInMonth(day),
      };

  /// First day of the period [day] belongs to. Weeks start on Monday, to
  /// match the calendar.
  DateTime periodStart(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return switch (period) {
      HabitPeriod.daily => d,
      HabitPeriod.weekly => d.subtract(Duration(days: d.weekday - 1)),
      HabitPeriod.monthly => DateTime(d.year, d.month, 1),
    };
  }

  /// Day after the period [day] belongs to (exclusive end).
  DateTime periodEnd(DateTime day) {
    final start = periodStart(day);
    return switch (period) {
      HabitPeriod.daily => start.add(const Duration(days: 1)),
      HabitPeriod.weekly => start.add(const Duration(days: 7)),
      HabitPeriod.monthly => DateTime(start.year, start.month + 1, 1),
    };
  }

  /// "1h30" for durations, "8 copos" for counters.
  String formatValue(double value) {
    if (isDuration) {
      final total = value.round();
      final h = total ~/ 60;
      final m = total % 60;
      if (h == 0) return '${m}min';
      if (m == 0) return '${h}h';
      return '${h}h${m.toString().padLeft(2, '0')}';
    }
    final rounded = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$rounded $unitLabel';
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'] ?? '',
      description: json['description'],
      iconName: json['icon_name'] ?? 'check_circle',
      colorValue: json['color_value'] ?? 0xFFFF8C42,
      imagePath: json['image_path'],
      goalType: HabitGoalType.values.firstWhere(
        (t) => t.name == json['goal_type'],
        orElse: () => HabitGoalType.counter,
      ),
      goalTarget: double.tryParse(json['goal_target'].toString()) ?? 1,
      goalUnit: json['goal_unit'],
      period: HabitPeriod.values.firstWhere(
        (p) => p.name == json['period'],
        orElse: () => HabitPeriod.daily,
      ),
      isArchived: json['is_archived'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

/// One logged amount. Several rows a day are normal; the period value is
/// their sum.
class HabitLog {
  final String id;
  final String userId;
  final String habitId;

  /// Data in YYYY-MM-DD format (matches the `date` column).
  final String logDate;

  /// Repeats for counter goals, minutes for duration goals.
  final double value;
  final DateTime? createdAt;

  const HabitLog({
    required this.id,
    required this.userId,
    required this.habitId,
    required this.logDate,
    required this.value,
    this.createdAt,
  });

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'],
      userId: json['user_id'],
      habitId: json['habit_id'],
      logDate: json['log_date'] ?? '',
      value: double.tryParse(json['value'].toString()) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

/// Sums [logs] per day, keyed by a midnight-normalized DateTime so the
/// calendar can look days up directly.
Map<DateTime, double> sumLogsByDay(List<HabitLog> logs) {
  final totals = <DateTime, double>{};
  for (final log in logs) {
    final day = DateTime.tryParse(log.logDate);
    if (day == null) continue;
    final key = DateTime(day.year, day.month, day.day);
    totals[key] = (totals[key] ?? 0) + log.value;
  }
  return totals;
}
