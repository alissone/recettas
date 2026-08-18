import 'dart:async';

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
  /// One future per card, so each section paints as soon as its own data
  /// lands instead of the whole page waiting on the slowest query, and
  /// the three run concurrently instead of in a chain.
  ///
  /// Null until the tab is first opened, which matters beyond tidiness:
  /// IndexedStack builds every tab up front and keeps it alive, so a
  /// spinner left in the tree would keep its AnimationController ticking
  /// every frame for the whole session. A FutureBuilder with a null
  /// future renders the idle placeholder instead, with nothing animating.
  Future<_NutritionData>? _nutrition;
  Future<List<GymEntry>>? _gym;
  Future<_HabitsData>? _habits;

  /// Last successful result per card. A refresh - switching back to this
  /// tab, returning from a tracker screen, pull-to-refresh - hands the
  /// FutureBuilder a new future, which resets its snapshot; without this
  /// the card would blank back to a spinner every time instead of
  /// leaving the current numbers up while the refetch runs.
  _NutritionData? _lastNutrition;
  List<GymEntry>? _lastGym;
  _HabitsData? _lastHabits;

  /// Static reference data: fetched once, reused by every reload.
  Map<NutrientId, Nutrient> _catalog = {};

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

  /// Every card summarizes the current month.
  DateTime get _monthStart {
    final now = today();
    return DateTime(now.year, now.month, 1);
  }

  String get _tomorrow => isoDate(today().add(const Duration(days: 1)));

  Future<void> _load() async {
    if (SupabaseService.currentUser == null) {
      if (mounted) {
        setState(() {
          _nutrition = null;
          _gym = null;
          _habits = null;
          // Signing out has to take the previous user's numbers with it.
          _lastNutrition = null;
          _lastGym = null;
          _lastHabits = null;
        });
      }
      return;
    }
    _reload(nutrition: true, gym: true, habits: true);
    // Pull-to-refresh has to keep spinning until everything settles. A
    // failure is reported by the card that owns it rather than thrown out
    // of here, which would leave the other two cards' results unshown.
    await Future.wait([
      _settled(_nutrition),
      _settled(_gym),
      _settled(_habits),
    ]);
  }

  /// Restarts the named fetches. Stale results can't win a race: a
  /// FutureBuilder handed a new future ignores the old one's completion.
  void _reload({
    bool nutrition = false,
    bool gym = false,
    bool habits = false,
  }) {
    setState(() {
      if (nutrition) _nutrition = _loadNutrition();
      if (gym) _gym = _loadGym();
      if (habits) _habits = _loadHabits();
    });
    // Attach an error handler right away: the FutureBuilder only
    // subscribes on the next build, and a fetch that fails before then
    // would otherwise surface as an unhandled async error.
    if (nutrition) unawaited(_settled(_nutrition));
    if (gym) unawaited(_settled(_gym));
    if (habits) unawaited(_settled(_habits));
  }

  /// Completes when [future] does, however it does. Every failure is
  /// already surfaced by the card's own FutureBuilder.
  static Future<void> _settled(Future<Object?>? future) async {
    if (future == null) return;
    try {
      await future;
    } catch (_) {}
  }

  Future<_NutritionData> _loadNutrition() async {
    // The nutrient catalog is static reference data; the active target
    // set is not, since Nutrição can change it.
    if (_catalog.isEmpty) {
      final catalog = await SupabaseService.getNutrientCatalog();
      _catalog = {for (final n in catalog) n.id: n};
    }
    // The targets chain and the month's entries have nothing to do with
    // each other, so they go out together.
    final (targets, entries) = await (
      _loadTargets(),
      SupabaseService.getFoodEntries(
        fromDate: isoDate(_monthStart),
        toDateExclusive: _tomorrow,
        catalog: _catalog,
      ),
    ).wait;
    return _lastNutrition =
        _NutritionData(targets: targets, monthEntries: entries);
  }

  /// The active recommendation set's amounts, falling back to the first
  /// shared set when the profile doesn't name one.
  Future<Map<NutrientId, double>> _loadTargets() async {
    String? setId;
    try {
      final profile = await SupabaseService.getProfile();
      setId = profile?['active_recommendation_set_id'];
    } catch (_) {}
    setId ??= (await SupabaseService.getRecommendationSets())
        .where((s) => s.isShared)
        .firstOrNull
        ?.id;
    if (setId == null) return {};
    return {
      for (final r in await SupabaseService.getRecommendations(setId))
        r.nutrient: r.amount,
    };
  }

  Future<List<GymEntry>> _loadGym() async {
    return _lastGym = await SupabaseService.getGymEntries(
      fromDate: isoDate(_monthStart),
      toDateExclusive: _tomorrow,
    );
  }

  Future<_HabitsData> _loadHabits() async {
    // A week of slack so weekly habits whose period started in the
    // previous month still add up correctly.
    final from = isoDate(_monthStart.subtract(const Duration(days: 7)));
    final (habits, logs) = await (
      SupabaseService.getHabits(),
      SupabaseService.getHabitLogs(
          fromDate: from, toDateExclusive: _tomorrow),
    ).wait;
    return _lastHabits = _HabitsData.from(habits, logs);
  }

  /// Opens a tracker screen, then refreshes just that card - the other
  /// two can't have changed while it was on screen.
  Future<void> _open(Widget screen, VoidCallback reload) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) reload();
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
              if (SupabaseService.currentUser == null)
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
                _buildAsyncCard<_NutritionData>(
                  icon: Icons.restaurant_outlined,
                  title: 'Nutrição',
                  screen: const NutritionScreen(),
                  future: _nutrition,
                  cached: _lastNutrition,
                  reload: () => _reload(nutrition: true),
                  bodyHeight: 118,
                  body: _buildNutritionBody,
                  monthLine: _nutritionMonthLine,
                ),
                const SizedBox(height: 14),
                _buildAsyncCard<List<GymEntry>>(
                  icon: Icons.fitness_center,
                  title: 'Academia',
                  screen: const GymScreen(),
                  future: _gym,
                  cached: _lastGym,
                  reload: () => _reload(gym: true),
                  bodyHeight: 48,
                  body: _buildGymBody,
                  monthLine: _gymMonthLine,
                ),
                const SizedBox(height: 14),
                _buildAsyncCard<_HabitsData>(
                  icon: Icons.self_improvement,
                  title: 'Hábitos',
                  screen: const HabitListScreen(),
                  future: _habits,
                  cached: _lastHabits,
                  reload: () => _reload(habits: true),
                  bodyHeight: 74,
                  body: _buildHabitsBody,
                  monthLine: _habitsMonthLine,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A card whose chrome - icon, title, chevron, tap target - is on
  /// screen from the first frame; only the body and the month line wait
  /// on data.
  Widget _buildAsyncCard<T>({
    required IconData icon,
    required String title,
    required Widget screen,
    required Future<T>? future,
    required T? cached,
    required VoidCallback reload,
    required double bodyHeight,
    required Widget Function(T data) body,
    required String Function(T data) monthLine,
  }) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        // Last good data outranks both the refresh spinner and a failed
        // refresh: stale numbers beat an empty card or an error row when
        // the card had something to show a moment ago.
        final data = snapshot.data ?? cached;

        final Widget content;
        if (data != null) {
          content = body(data);
        } else if (snapshot.hasError) {
          content = _buildCardError(reload);
        } else {
          content = _buildCardPlaceholder(bodyHeight,
              spinning: future != null);
        }

        return _buildSummaryCard(
          icon: icon,
          title: title,
          screen: screen,
          reload: reload,
          monthLine: data == null ? '' : monthLine(data),
          body: content,
        );
      },
    );
  }

  /// Holds roughly the card's final height while its data lands, so the
  /// page doesn't jump as each section fills in. Spins only while a fetch
  /// is actually in flight - see the future fields on the state.
  Widget _buildCardPlaceholder(double height, {required bool spinning}) {
    return SizedBox(
      height: height,
      child: spinning
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppTheme.primaryOrange),
              ),
            )
          : null,
    );
  }

  /// One card failing leaves the other two showing their data, so the
  /// retry is scoped to this card rather than reloading the page.
  Widget _buildCardError(VoidCallback reload) {
    return Row(
      children: [
        Expanded(
          child: Text('Não foi possível carregar.',
              style:
                  AppTheme.caption.copyWith(fontWeight: FontWeight.w400)),
        ),
        TextButton(
          onPressed: reload,
          child: const Text('Tentar novamente'),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String monthLine,
    required Widget body,
    required Widget screen,
    required VoidCallback reload,
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
          onTap: () => _open(screen, reload),
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
                // Empty until this card's data lands.
                if (monthLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(monthLine, style: AppTheme.caption),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nutritionMonthLine(_NutritionData data) =>
      data.caloriesByDay.isEmpty
          ? 'Nenhum registro neste mês'
          : 'Média do mês: ${data.averageCalories.round()} kcal/dia';

  Widget _buildNutritionBody(_NutritionData data) {
    final iso = isoDate(today());
    final todayEntries =
        data.monthEntries.where((e) => e.entryDate == iso).toList();
    final totals = calculateTotals(todayEntries);
    final kcal = totals[NutrientId.calories] ?? 0;
    final kcalTarget = data.targets[NutrientId.calories];

    return Column(
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
            data.targets[NutrientId.protein]),
        const SizedBox(height: 6),
        _buildMacroBar('Carboidratos',
            totals[NutrientId.carbohydrates] ?? 0,
            data.targets[NutrientId.carbohydrates]),
        const SizedBox(height: 6),
        _buildMacroBar('Gorduras', totals[NutrientId.fat] ?? 0,
            data.targets[NutrientId.fat]),
      ],
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

  String _gymMonthLine(List<GymEntry> monthEntries) {
    final days = monthEntries.map((e) => e.entryDate).toSet().length;
    return '$days ${days == 1 ? 'treino' : 'treinos'} neste mês';
  }

  Widget _buildGymBody(List<GymEntry> monthEntries) {
    final iso = isoDate(today());
    final todayEntries =
        monthEntries.where((e) => e.entryDate == iso).toList();
    if (todayEntries.isEmpty) {
      return Text('Nenhum exercício registrado hoje.',
          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400));
    }

    final sets = todayEntries.fold<int>(0, (s, e) => s + e.sets);
    final volume = todayEntries.fold<double>(0, (s, e) => s + e.volume);

    return Row(
      children: [
        _buildStat('Exercícios', '${todayEntries.length}'),
        const SizedBox(width: 24),
        _buildStat('Séries', '$sets'),
        const SizedBox(width: 24),
        _buildStat('Volume', volume > 0 ? '${volume.round()} kg' : '—'),
      ],
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

  String _habitsMonthLine(_HabitsData data) => data.habits.isEmpty
      ? 'Nenhum hábito criado ainda'
      : 'Melhor sequência no mês: ${data.bestStreak} '
          '${data.bestStreak == 1 ? 'dia' : 'dias'}';

  Widget _buildHabitsBody(_HabitsData data) {
    if (data.habits.isEmpty) {
      return Text('Toque para criar seu primeiro hábito.',
          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400));
    }

    final now = today();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${data.doneToday} de ${data.habits.length}',
                style: AppTheme.headingMedium),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('concluídos hoje', style: AppTheme.caption),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final habit in data.habits)
              _buildHabitDot(habit, now, data.totals),
          ],
        ),
      ],
    );
  }

  Widget _buildHabitDot(Habit habit, DateTime day,
      Map<String, Map<DateTime, double>> allTotals) {
    final totals = allTotals[habit.id] ?? const {};
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

/// What the Nutrição card needs, with the month rollup precomputed at
/// load rather than on every rebuild.
class _NutritionData {
  final Map<NutrientId, double> targets;
  final List<FoodEntry> monthEntries;

  /// Calories per YYYY-MM-DD, holding only the days that have entries:
  /// an unlogged day isn't a zero-calorie day, so it must not drag the
  /// average down.
  final Map<String, double> caloriesByDay;

  _NutritionData({
    required this.targets,
    required this.monthEntries,
  }) : caloriesByDay = {} {
    for (final entry in monthEntries) {
      caloriesByDay[entry.entryDate] =
          (caloriesByDay[entry.entryDate] ?? 0) +
              entry.nutrient(NutrientId.calories);
    }
  }

  double get averageCalories => caloriesByDay.isEmpty
      ? 0
      : caloriesByDay.values.reduce((a, b) => a + b) /
          caloriesByDay.length;
}

/// What the Hábitos card needs. The streak scan walks every habit across
/// every day of the window, so it runs once at load, not per rebuild.
class _HabitsData {
  final List<Habit> habits;

  /// Habit id -> day -> total logged that day.
  final Map<String, Map<DateTime, double>> totals;
  final int doneToday;

  /// Longest run of complete days inside the loaded window - this month
  /// plus a week of slack - across all habits.
  final int bestStreak;

  const _HabitsData({
    required this.habits,
    required this.totals,
    required this.doneToday,
    required this.bestStreak,
  });

  factory _HabitsData.from(List<Habit> habits, List<HabitLog> logs) {
    final totals = {
      for (final habit in habits)
        habit.id: sumLogsByDay(
            logs.where((l) => l.habitId == habit.id).toList()),
    };

    final now = today();
    final start = DateTime(now.year, now.month, 1)
        .subtract(const Duration(days: 7));
    var doneToday = 0;
    var bestStreak = 0;

    for (final habit in habits) {
      final habitTotals = totals[habit.id] ?? const <DateTime, double>{};
      final target = habit.dailyTarget(now);
      if (target > 0 && (habitTotals[now] ?? 0) >= target) doneToday++;

      var run = 0;
      for (var day = start;
          !day.isAfter(now);
          day = day.add(const Duration(days: 1))) {
        final dayTarget = habit.dailyTarget(day);
        if (dayTarget > 0 && (habitTotals[day] ?? 0) >= dayTarget) {
          run++;
          if (run > bestStreak) bestStreak = run;
        } else {
          run = 0;
        }
      }
    }

    return _HabitsData(
      habits: habits,
      totals: totals,
      doneToday: doneToday,
      bestStreak: bestStreak,
    );
  }
}
