import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/food.dart';
import '../models/gym_entry.dart';
import '../models/habit.dart';
import '../models/nutrient.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import 'gym_screen.dart';
import 'habit_list_screen.dart';
import 'home_shell.dart' show homeTabIndex;
import 'nutrition_screen.dart';

/// "Hábitos" tab: today at a glance across the three trackers. Each card
/// opens the screen where the actual logging happens.
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  /// Index of this screen in the bottom navigation bar.
  static const tabIndex = 4;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  /// A fetch is in flight. Starts false: until the user opens this tab
  /// nothing is loading, and a spinner left in the tree would keep its
  /// AnimationController ticking every frame for the whole session -
  /// IndexedStack keeps unselected tabs alive and animating.
  bool _isLoading = false;

  /// At least one fetch finished, so a refresh shouldn't blank the page.
  bool _hasLoaded = false;
  int _loadSeq = 0;

  Map<NutrientId, Nutrient> _catalog = {};
  Map<NutrientId, double> _targets = {};
  List<FoodEntry> _monthFoodEntries = [];
  List<GymEntry> _monthGymEntries = [];
  List<Habit> _habits = [];
  Map<String, Map<DateTime, double>> _habitTotals = {};

  @override
  void initState() {
    super.initState();
    // IndexedStack builds every tab up front and keeps it alive, so
    // initState runs once, at app start. Only fetch if this tab is the
    // one being shown; otherwise wait until the user switches to it.
    homeTabIndex.addListener(_onTabChanged);
    if (homeTabIndex.value == HabitsScreen.tabIndex) _load();
  }

  @override
  void dispose() {
    homeTabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (homeTabIndex.value == HabitsScreen.tabIndex) _load();
  }

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
      }
      return;
    }
    final seq = ++_loadSeq;
    if (!_hasLoaded) setState(() => _isLoading = true);
    try {
      final now = today();
      final monthStart = DateTime(now.year, now.month, 1);
      final tomorrow = isoDate(now.add(const Duration(days: 1)));
      // A week of slack so weekly habits whose period started in the
      // previous month still add up correctly.
      final habitsFrom =
          isoDate(monthStart.subtract(const Duration(days: 7)));

      // The nutrient catalog is static reference data; the active set is
      // not, since Nutrição can change it.
      if (_catalog.isEmpty) {
        final catalogList = await SupabaseService.getNutrientCatalog();
        _catalog = {for (final n in catalogList) n.id: n};
      }

      String? setId;
      try {
        final profile = await SupabaseService.getProfile();
        setId = profile?['active_recommendation_set_id'];
      } catch (_) {}
      setId ??= (await SupabaseService.getRecommendationSets())
          .where((s) => s.isShared)
          .firstOrNull
          ?.id;
      _targets = setId == null
          ? {}
          : {
              for (final r
                  in await SupabaseService.getRecommendations(setId))
                r.nutrient: r.amount,
            };

      final foodEntries = await SupabaseService.getFoodEntries(
        fromDate: isoDate(monthStart),
        toDateExclusive: tomorrow,
        catalog: _catalog,
      );
      final gymEntries = await SupabaseService.getGymEntries(
        fromDate: isoDate(monthStart),
        toDateExclusive: tomorrow,
      );
      final habits = await SupabaseService.getHabits();
      final logs = await SupabaseService.getHabitLogs(
        fromDate: habitsFrom,
        toDateExclusive: tomorrow,
      );

      final totals = <String, Map<DateTime, double>>{};
      for (final habit in habits) {
        totals[habit.id] = sumLogsByDay(
            logs.where((l) => l.habitId == habit.id).toList());
      }

      if (mounted && seq == _loadSeq) {
        setState(() {
          _monthFoodEntries = foodEntries;
          _monthGymEntries = gymEntries;
          _habits = habits;
          _habitTotals = totals;
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted && seq == _loadSeq) {
        // Mark it loaded even on failure, so retrying via pull-to-refresh
        // doesn't drop back to a full-page spinner.
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar: $e')));
      }
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primaryOrange,
          child: ListView(
            // Short content still has to drag for pull-to-refresh.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Hábitos', style: AppTheme.headingLarge),
              const SizedBox(height: 4),
              Text(
                'Nutrição, academia e rotina',
                style: AppTheme.bodyText
                    .copyWith(color: AppTheme.mediumBrown),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryOrange),
                  ),
                )
              else if (SupabaseService.currentUser == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'Entre na sua conta para acompanhar seus hábitos.',
                    textAlign: TextAlign.center,
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w400),
                  ),
                )
              else ...[
                _buildNutritionCard(),
                const SizedBox(height: 14),
                _buildGymCard(),
                const SizedBox(height: 14),
                _buildHabitsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String monthLine,
    required Widget body,
    required Widget screen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => _open(screen),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusXSmall),
                      ),
                      child: Icon(icon,
                          color: AppTheme.primaryOrange, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child:
                            Text(title, style: AppTheme.sectionTitle)),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.mediumBrown),
                  ],
                ),
                const SizedBox(height: 14),
                body,
                const SizedBox(height: 10),
                Text(monthLine, style: AppTheme.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionCard() {
    final iso = isoDate(today());
    final todayEntries =
        _monthFoodEntries.where((e) => e.entryDate == iso).toList();
    final totals = calculateTotals(todayEntries);
    final kcal = totals[NutrientId.calories] ?? 0;
    final kcalTarget = _targets[NutrientId.calories];

    // Average over the days that actually have entries, not the whole
    // month - an unlogged day isn't a zero-calorie day.
    final byDay = <String, double>{};
    for (final entry in _monthFoodEntries) {
      byDay[entry.entryDate] = (byDay[entry.entryDate] ?? 0) +
          entry.nutrient(NutrientId.calories);
    }
    final average = byDay.isEmpty
        ? 0.0
        : byDay.values.reduce((a, b) => a + b) / byDay.length;

    return _buildSummaryCard(
      icon: Icons.restaurant_outlined,
      title: 'Nutrição',
      monthLine: byDay.isEmpty
          ? 'Nenhum registro neste mês'
          : 'Média do mês: ${average.round()} kcal/dia',
      screen: const NutritionScreen(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${kcal.round()}', style: AppTheme.headingLarge),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  kcalTarget != null
                      ? 'de ${kcalTarget.round()} kcal hoje'
                      : 'kcal hoje',
                  style: AppTheme.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMacroBar('Proteína', totals[NutrientId.protein] ?? 0,
              _targets[NutrientId.protein]),
          const SizedBox(height: 6),
          _buildMacroBar('Carboidratos',
              totals[NutrientId.carbohydrates] ?? 0,
              _targets[NutrientId.carbohydrates]),
          const SizedBox(height: 6),
          _buildMacroBar('Gorduras', totals[NutrientId.fat] ?? 0,
              _targets[NutrientId.fat]),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, double value, double? target) {
    final fraction = target != null && target > 0 ? value / target : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: AppTheme.caption),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor:
                  AppTheme.primaryOrange.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(
                  AppTheme.primaryOrange),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            target != null
                ? '${value.round()}/${target.round()} g'
                : '${value.round()} g',
            style: AppTheme.caption,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildGymCard() {
    final iso = isoDate(today());
    final todayEntries =
        _monthGymEntries.where((e) => e.entryDate == iso).toList();
    final sets = todayEntries.fold<int>(0, (s, e) => s + e.sets);
    final volume =
        todayEntries.fold<double>(0, (s, e) => s + e.volume);
    final trainingDays =
        _monthGymEntries.map((e) => e.entryDate).toSet().length;

    return _buildSummaryCard(
      icon: Icons.fitness_center,
      title: 'Academia',
      monthLine: '$trainingDays '
          '${trainingDays == 1 ? 'treino' : 'treinos'} neste mês',
      screen: const GymScreen(),
      body: todayEntries.isEmpty
          ? Text('Nenhum exercício registrado hoje.',
              style:
                  AppTheme.caption.copyWith(fontWeight: FontWeight.w400))
          : Row(
              children: [
                _buildStat('Exercícios', '${todayEntries.length}'),
                const SizedBox(width: 24),
                _buildStat('Séries', '$sets'),
                const SizedBox(width: 24),
                _buildStat(
                    'Volume', volume > 0 ? '${volume.round()} kg' : '—'),
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

  Widget _buildHabitsCard() {
    final now = today();
    var doneToday = 0;
    var bestStreak = 0;

    for (final habit in _habits) {
      final totals = _habitTotals[habit.id] ?? const {};
      final target = habit.dailyTarget(now);
      if (target > 0 && (totals[now] ?? 0) >= target) doneToday++;

      // Longest run inside the loaded window, which is this month plus a
      // week of slack.
      final start = DateTime(now.year, now.month, 1)
          .subtract(const Duration(days: 7));
      var run = 0;
      for (var day = start;
          !day.isAfter(now);
          day = day.add(const Duration(days: 1))) {
        final dayTarget = habit.dailyTarget(day);
        if (dayTarget > 0 && (totals[day] ?? 0) >= dayTarget) {
          run++;
          if (run > bestStreak) bestStreak = run;
        } else {
          run = 0;
        }
      }
    }

    return _buildSummaryCard(
      icon: Icons.self_improvement,
      title: 'Hábitos',
      monthLine: _habits.isEmpty
          ? 'Nenhum hábito criado ainda'
          : 'Melhor sequência no mês: $bestStreak '
              '${bestStreak == 1 ? 'dia' : 'dias'}',
      screen: const HabitListScreen(),
      body: _habits.isEmpty
          ? Text('Toque para criar seu primeiro hábito.',
              style:
                  AppTheme.caption.copyWith(fontWeight: FontWeight.w400))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$doneToday de ${_habits.length}',
                        style: AppTheme.headingMedium),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('concluídos hoje',
                          style: AppTheme.caption),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final habit in _habits)
                      _buildHabitDot(habit, now),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildHabitDot(Habit habit, DateTime day) {
    final totals = _habitTotals[habit.id] ?? const {};
    final target = habit.dailyTarget(day);
    final isDone = target > 0 && (totals[day] ?? 0) >= target;

    return Tooltip(
      message: habit.name,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDone
              ? habit.color
              : habit.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
        ),
        child: Icon(
          habit.icon,
          size: 17,
          color: isDone ? Colors.white : habit.color,
        ),
      ),
    );
  }
}
