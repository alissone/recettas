import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/habit.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import '../widgets/habit_calendar.dart';
import '../widgets/remote_image.dart';
import 'habit_list_screen.dart' show HabitSheet;

/// One habit up close: the progress of the current period, a month
/// heatmap of every day, streak stats, and a per-day sheet to add or
/// remove individual logs.
class HabitDetailScreen extends StatefulWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late Habit _habit;
  bool _isLoading = true;
  List<HabitLog> _logs = [];
  Map<DateTime, double> _dayTotals = {};
  int _loadSeq = 0;

  /// First day of the visible month.
  late DateTime _month;

  /// How far back the streak stats look.
  static const _historyDays = 180;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    final now = today();
    _month = DateTime(now.year, now.month, 1);
    _load();
  }

  bool get _isAtCurrentMonth {
    final now = today();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    try {
      // One fetch covers both the visible month and the window the
      // streak stats need.
      final from = _month.subtract(const Duration(days: _historyDays));
      final to = DateTime(_month.year, _month.month + 1, 1);
      final logs = await SupabaseService.getHabitLogs(
        fromDate: isoDate(from),
        toDateExclusive: isoDate(to),
        habitId: _habit.id,
      );
      if (mounted && seq == _loadSeq) {
        setState(() {
          _logs = logs;
          _dayTotals = sumLogsByDay(logs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && seq == _loadSeq) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar: $e')));
      }
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    final now = today();
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() {
      _month = next;
      _isLoading = true;
    });
    _load();
  }

  // --- Derived stats ---

  bool _isDayComplete(DateTime day) {
    final target = _habit.dailyTarget(day);
    if (target <= 0) return false;
    return (_dayTotals[day] ?? 0) >= target;
  }

  /// Total logged over the period that contains today.
  double get _periodValue {
    final now = today();
    final start = _habit.periodStart(now);
    final end = _habit.periodEnd(now);
    var total = 0.0;
    _dayTotals.forEach((day, value) {
      if (!day.isBefore(start) && day.isBefore(end)) total += value;
    });
    return total;
  }

  /// Consecutive complete days ending today. A day that hasn't been
  /// logged yet doesn't break the streak - the count just starts at
  /// yesterday.
  int get _currentStreak {
    var day = today();
    if (!_isDayComplete(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (_isDayComplete(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest run of complete days inside the loaded window.
  int get _bestStreak {
    final start = _month.subtract(const Duration(days: _historyDays));
    final end = today();
    var best = 0;
    var run = 0;
    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      if (_isDayComplete(day)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  int get _completeDaysInMonth {
    final total = daysInMonth(_month);
    var count = 0;
    for (var i = 1; i <= total; i++) {
      if (_isDayComplete(DateTime(_month.year, _month.month, i))) count++;
    }
    return count;
  }

  // --- Actions ---

  Future<void> _addLog(DateTime day, double value) async {
    if (value <= 0) return;
    try {
      await SupabaseService.addHabitLog(
        habitId: _habit.id,
        logDate: isoDate(day),
        value: value,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao registrar: $e')));
      }
    }
  }

  Future<void> _deleteLog(HabitLog log) async {
    try {
      await SupabaseService.deleteHabitLog(log.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => HabitSheet(existing: _habit),
    );
    if (saved != true) return;

    // Pull the edited row back so the header and targets stay in sync.
    try {
      final habits = await SupabaseService.getHabits();
      final updated = habits.where((h) => h.id == _habit.id).firstOrNull;
      if (mounted && updated != null) setState(() => _habit = updated);
    } catch (_) {}
    await _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Excluir hábito', style: AppTheme.headingMedium),
        content: Text(
          'Isso apaga "${_habit.name}" e todos os registros dele.',
          style: AppTheme.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseService.deleteHabit(_habit.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  Future<void> _showDaySheet(DateTime day) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (sheetContext) {
        final dayLogs = _logs
            .where((l) => l.logDate == isoDate(day))
            .toList();
        final controller = TextEditingController();

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatDayMonth(day), style: AppTheme.headingMedium),
              const SizedBox(height: 4),
              Text(
                '${_habit.formatValue(_dayTotals[day] ?? 0)} de '
                '${_habit.formatValue(_habit.dailyTarget(day))} no dia',
                style: AppTheme.caption,
              ),
              const SizedBox(height: 16),
              if (dayLogs.isEmpty)
                Text('Nenhum registro neste dia.',
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w400)),
              for (final log in dayLogs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(_habit.icon, size: 18, color: _habit.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_habit.formatValue(log.value),
                            style: AppTheme.bodyText),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _deleteLog(log);
                        },
                        icon: Icon(Icons.close,
                            size: 18,
                            color: AppTheme.mediumBrown
                                .withValues(alpha: 0.6)),
                        tooltip: 'Excluir',
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      decoration: InputDecoration(
                        labelText: _habit.isDuration
                            ? 'Minutos'
                            : _habit.unitLabel,
                        filled: true,
                        fillColor: AppTheme.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final value = double.tryParse(
                          controller.text.replaceAll(',', '.'));
                      Navigator.pop(sheetContext);
                      if (value != null) _addLog(day, value);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _habit.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                    child: const Text('Adicionar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: Text(_habit.name),
        actions: [
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
          ),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir',
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
                  if (_habit.imagePath != null) ...[
                    RemoteImage(
                      path: _habit.imagePath,
                      width: double.infinity,
                      height: 160,
                      placeholder: _habit.icon,
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildProgressCard(),
                  const SizedBox(height: 20),
                  _buildCalendarCard(),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final value = _periodValue;
    final fraction =
        _habit.goalTarget > 0 ? value / _habit.goalTarget : 0.0;

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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _habit.color,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(_habit.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_habit.goalLabel, style: AppTheme.valueBold),
                    if (_habit.description != null &&
                        _habit.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_habit.description!,
                          style: AppTheme.caption
                              .copyWith(fontWeight: FontWeight.w400)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_habit.formatValue(value)} '
            '${_habit.periodLabel.replaceFirst('por ', 'neste ')}',
            style: AppTheme.headingMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: _habit.color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(_habit.color),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStat('Sequência atual', '$_currentStreak d'),
              const SizedBox(width: 24),
              _buildStat('Melhor sequência', '$_bestStreak d'),
              const SizedBox(width: 24),
              _buildStat('Completos no mês', '$_completeDaysInMonth'),
            ],
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
        Text(value, style: AppTheme.valueBold),
      ],
    );
  }

  Widget _buildCalendarCard() {
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
          HabitCalendar(
            month: _month,
            habit: _habit,
            totals: _dayTotals,
            onDayTap: _showDaySheet,
          ),
          const SizedBox(height: 14),
          const HabitCalendarLegend(),
          const SizedBox(height: 6),
          Text(
            'Toque em um dia para ver ou editar os registros.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
