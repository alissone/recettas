import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/energy_estimate.dart';
import '../models/food.dart';
import '../models/nutrient.dart';
import '../models/recipe.dart';
import '../models/weight_entry.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import 'food_library_screen.dart';
import 'nutrient_targets_screen.dart';

/// Granularity of the nutrient trend chart's x-axis.
enum _TrendRange { day, week, month }

/// Nutrition log: pick a food and an amount, and see the day's nutrient
/// intake against the active recommendation set. The food catalog is
/// seeded in SQL; this screen only reads it.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  bool _isLoading = true;

  /// Static reference data, fetched once. Packages and recipes are built
  /// on top of [_foods] and are what the "pacote" and "receita" entry
  /// flows pick from; the recipes are the ones on the "Receitas" tab,
  /// minus any that have no ingredient list to score.
  Map<NutrientId, Nutrient> _catalog = {};
  List<Food> _foods = [];
  List<FoodPackage> _packages = [];
  List<Recipe> _recipes = [];

  /// Daily targets from whichever set the profile points at. Which set
  /// that is - and what's in it - is owned by NutrientTargetsScreen.
  Map<NutrientId, double> _targets = {};

  /// The body-profile row from Profile - sex, age, height, weight, goal,
  /// training volume. Drives the weight/BMI projection and, for calories,
  /// the computed RMR/TDEE estimate below.
  Map<String, dynamic>? _profile;

  double? get _heightCm => _profileDouble('height_cm');
  double? get _weightKg => _profileDouble('weight_kg');
  double? _profileDouble(String key) {
    final v = _profile?[key];
    return v == null ? null : double.tryParse(v.toString());
  }

  /// Null until sex, age, height and weight are all filled in on Profile.
  EnergyEstimate? get _energyEstimate => EnergyEstimate.fromProfile(_profile);

  /// Check-ins from the last ~6 months, for the body weight card. Both its
  /// charts are sliced out of this one list rather than queried twice.
  List<WeightEntry> _weightHistory = [];

  /// Entries for the whole visible range; the day's list is filtered out
  /// of this so paging a day never costs a second request.
  List<FoodEntry> _rangeEntries = [];

  /// Last day of the visible range, and the day the totals are for.
  DateTime _day = today();
  _TrendRange _trendRange = _TrendRange.week;
  NutrientCategory _category = NutrientCategory.macronutrient;
  NutrientId? _selectedNutrient;
  DateTime? _selectedTrendDay;
  int _loadSeq = 0;

  int get _rangeDays => switch (_trendRange) {
        _TrendRange.day => 1,
        _TrendRange.week => 7,
        _TrendRange.month => 30,
      };

  bool get _isAtToday => !_day.isBefore(today());

  List<FoodEntry> get _dayEntries {
    final iso = isoDate(_day);
    return _rangeEntries.where((e) => e.entryDate == iso).toList();
  }

  List<DateTime> get _rangeDaysList => [
        for (var i = _rangeDays - 1; i >= 0; i--)
          _day.subtract(Duration(days: i)),
      ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (SupabaseService.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final catalogList = await SupabaseService.getNutrientCatalog();
      final catalog = {for (final n in catalogList) n.id: n};
      final foods = await SupabaseService.getFoods(catalog);
      final packages = await SupabaseService.getFoodPackages();
      final recipes = await _loggableRecipes(catalog);
      final sets = await SupabaseService.getRecommendationSets();
      final weightHistory = await SupabaseService.getWeightEntries(
          from: DateTime.now().subtract(const Duration(days: 182)));

      String? activeSetId;
      Map<String, dynamic>? profile;
      try {
        profile = await SupabaseService.getProfile();
        activeSetId = profile?['active_recommendation_set_id'];
      } catch (_) {
        // Profile row missing: just run without targets.
      }
      // Fall back to the first shared preset so a fresh account still
      // sees percentages.
      activeSetId ??= sets
          .where((s) => s.isShared)
          .firstOrNull
          ?.id;

      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _foods = foods;
        _packages = packages;
        _recipes = recipes;
        _profile = profile;
        _weightHistory = weightHistory;
      });
      await _loadTargets(activeSetId);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar: $e')));
      }
    }
  }

  /// A recipe with no ingredient list - only a method, or one written
  /// before the list existed - has nothing to add up, so it is left out
  /// of the picker rather than offered as a zero-calorie meal.
  Future<List<Recipe>> _loggableRecipes(
      Map<NutrientId, Nutrient> catalog) async {
    final recipes = await SupabaseService.getRecipes(catalog);
    return recipes.where((r) => r.isLoggable).toList();
  }

  Future<void> _loadTargets(String? setId) async {
    if (setId == null) {
      if (mounted) setState(() => _targets = {});
      return;
    }
    final recommendations =
        await SupabaseService.getRecommendations(setId);
    if (!mounted) return;
    setState(() {
      _targets = {
        for (final r in recommendations) r.nutrient: r.amount,
      };
    });
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    try {
      final days = _rangeDaysList;
      final entries = await SupabaseService.getFoodEntries(
        fromDate: isoDate(days.first),
        toDateExclusive:
            isoDate(days.last.add(const Duration(days: 1))),
        catalog: _catalog,
      );
      if (mounted && seq == _loadSeq) {
        setState(() {
          _rangeEntries = entries;
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

  void _changeDay(int delta) {
    final next = _day.add(Duration(days: delta));
    if (next.isAfter(today())) return;
    setState(() {
      _day = next;
      _selectedTrendDay = null;
      _isLoading = true;
    });
    _load();
  }

  /// Moves the trend range back/forward by one week or month.
  void _page(int direction) {
    var next = _day.add(Duration(days: direction * _rangeDays));
    if (next.isAfter(today())) next = today();
    if (next == _day) return;
    setState(() {
      _day = next;
      _selectedTrendDay = null;
      _isLoading = true;
    });
    _load();
  }

  /// The targets screen owns both picking a set and editing its
  /// numbers, and reports back whether anything changed.
  Future<void> _openTargets() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NutrientTargetsScreen()),
    );
    if (changed != true || !mounted) return;

    // The active set may now be a different one, so re-read it.
    try {
      String? setId;
      try {
        final profile = await SupabaseService.getProfile();
        setId = profile?['active_recommendation_set_id'];
      } catch (_) {}
      setId ??= (await SupabaseService.getRecommendationSets())
          .where((s) => s.isShared)
          .firstOrNull
          ?.id;
      await _loadTargets(setId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao recarregar metas: $e')));
      }
    }
  }

  /// The three things a day can be made of: a raw ingredient in grams, a
  /// package of one, or a whole recipe.
  Future<void> _addEntry() async {
    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Nenhum alimento cadastrado. Adicione-os no Supabase.')));
      return;
    }
    final kind = await showModalBottomSheet<_EntryKind>(
      context: context,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => const _EntryKindSheet(),
    );
    if (kind == null || !mounted) return;

    switch (kind) {
      case _EntryKind.ingredient:
        await _addFromOptions('Adicionar ingrediente', _ingredientOptions());
      case _EntryKind.package:
        if (_packages.isEmpty) {
          _promptLibrary('Nenhum pacote cadastrado ainda.');
          return;
        }
        await _addFromOptions('Adicionar pacote', _packageOptions());
      case _EntryKind.recipe:
        if (_recipes.isEmpty) {
          // Recipes with no ingredient list were filtered out, so this
          // covers both "none written" and "none measurable yet".
          _promptLibrary('Nenhuma receita com lista de ingredientes.');
          return;
        }
        await _addFromOptions('Adicionar receita', _recipeOptions());
      case _EntryKind.manage:
        await _openLibrary();
    }
  }

  /// Search, pick, type an amount, save - identical for all three kinds,
  /// which differ only in what a unit of the amount means.
  Future<void> _addFromOptions(
      String title, List<_LogOption> options) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => _EntrySheet(
        title: title,
        options: options,
        entryDate: isoDate(_day),
      ),
    );
    if (saved == true) await _load();
  }

  void _promptLibrary(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Criar',
        textColor: AppTheme.primaryOrange,
        onPressed: _openLibrary,
      ),
    ));
  }

  List<_LogOption> _ingredientOptions() {
    return [
      for (final food in _foods)
        _LogOption(
          title: food.label,
          subtitle: '${food.get(NutrientId.calories).round()} kcal por '
              '${formatNutrientAmount(food.baseAmount)} ${food.baseUnit}',
          unitSuffix: food.baseUnit,
          defaultAmount: food.baseAmount,
          kcalPerUnit: food.baseAmount <= 0
              ? 0
              : food.get(NutrientId.calories) / food.baseAmount,
          save: (entryDate, amount) => SupabaseService.addFoodEntry(
            entryDate: entryDate,
            foodId: food.id,
            amount: amount,
          ),
        ),
    ];
  }

  /// The amount is a number of packs; what gets logged is that many times
  /// the pack's weight, against the underlying ingredient.
  List<_LogOption> _packageOptions() {
    final foodsById = {for (final food in _foods) food.id: food};
    final options = <_LogOption>[];
    for (final package in _packages) {
      final food = foodsById[package.foodId];
      if (food == null) continue;
      final kcal = food.baseAmount <= 0
          ? 0.0
          : food.get(NutrientId.calories) *
              package.amount /
              food.baseAmount;
      options.add(_LogOption(
        title: '${food.label} · ${package.labelFor(food.baseUnit)}',
        subtitle: '${formatNutrientAmount(package.amount)} '
            '${food.baseUnit} · ${kcal.round()} kcal por unidade',
        amountLabel: 'Quantidade',
        unitSuffix: 'un',
        defaultAmount: 1,
        kcalPerUnit: kcal,
        save: (entryDate, amount) => SupabaseService.addFoodEntry(
          entryDate: entryDate,
          foodId: food.id,
          packageId: package.id,
          amount: amount * package.amount,
        ),
      ));
    }
    return options;
  }

  List<_LogOption> _recipeOptions() {
    return [
      for (final recipe in _recipes)
        () {
          final weight = recipe.weight;
          final kcal =
              recipe.nutrients[NutrientId.calories]?.amount ?? 0;
          return _LogOption(
            title: recipe.name,
            subtitle: '${recipe.ingredients.length} ingredientes · '
                '${formatQuantity(weight)} g · '
                '${weight > 0 ? (kcal * 100 / weight).round() : 0} kcal '
                'por 100 g',
            unitSuffix: 'g',
            defaultAmount: weight,
            kcalPerUnit: weight > 0 ? kcal / weight : 0,
            save: (entryDate, amount) => SupabaseService.addFoodEntry(
              entryDate: entryDate,
              recipeId: recipe.id,
              amount: amount,
            ),
          );
        }(),
    ];
  }

  /// Editing a recipe changes what every entry made from it is worth, so
  /// the day's numbers are reloaded alongside the catalogs.
  Future<void> _openLibrary() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FoodLibraryScreen()),
    );
    if (changed != true || !mounted) return;
    try {
      final packages = await SupabaseService.getFoodPackages();
      final recipes = await _loggableRecipes(_catalog);
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _recipes = recipes;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao recarregar: $e')));
      }
    }
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    try {
      await SupabaseService.deleteFoodEntry(entry.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  /// Easter egg: tapping a logged food shows what a similar number of
  /// calories looks like as a healthy alternative, picked at random on
  /// every tap so the comparison stays fresh.
  void _showCalorieEquivalent(FoodEntry entry) {
    final kcal = entry.nutrient(NutrientId.calories);
    if (kcal <= 0) return;
    final ref = _healthyFoodRefs[math.Random().nextInt(_healthyFoodRefs.length)];
    final count = kcal / ref.kcal;
    final rounded = double.parse(count.toStringAsFixed(1));
    final label = rounded == 1.0 ? ref.singular : ref.plural;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: const Text('🍉 Você sabia?'),
        content: Text(
          'Essas ${kcal.round()} calorias equivalem a '
          'aproximadamente ${formatNutrientAmount(count)} $label.',
          style: AppTheme.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar',
                style: TextStyle(color: AppTheme.primaryOrange)),
          ),
        ],
      ),
    );
  }

  // --- Derived data ---

  /// Rows for the selected category: everything with a target or an
  /// actual intake. Nutrients nobody tracks stay out of the way.
  List<_NutrientRow> _rowsFor(Map<NutrientId, double> totals) {
    final rows = <_NutrientRow>[];
    for (final nutrient in _catalog.values) {
      if (nutrient.category != _category) continue;
      final intake = totals[nutrient.id] ?? 0;
      final target = _targets[nutrient.id];
      if (intake <= 0 && (target == null || target <= 0)) continue;
      rows.add(_NutrientRow(
        nutrient: nutrient,
        intake: intake,
        target: target != null && target > 0 ? target : null,
      ));
    }
    rows.sort((a, b) =>
        a.nutrient.sortOrder.compareTo(b.nutrient.sortOrder));
    return rows;
  }

  /// Every group the catalog has nutrients for, ordered the way the
  /// printed panels are (by sort_order, not enum declaration order):
  /// Principais, Açúcares, Ácidos graxos, Esteróis, Aminoácidos,
  /// Vitaminas, Carotenoides, Minerais, Fitoquímicos, Outros.
  ///
  /// Every group is always offered, even when today has nothing in it -
  /// gating the chips on "has a value or a target" hid vitamins, amino
  /// acids and the rest behind whichever nutrients the active target set
  /// happened to mention.
  List<NutrientCategory> get _categories {
    final firstSort = <NutrientCategory, int>{};
    for (final nutrient in _catalog.values) {
      final current = firstSort[nutrient.category];
      if (current == null || nutrient.sortOrder < current) {
        firstSort[nutrient.category] = nutrient.sortOrder;
      }
    }
    return firstSort.keys.toList()
      ..sort((a, b) => firstSort[a]!.compareTo(firstSort[b]!));
  }

  /// How many nutrients each group would show, so a chip can say whether
  /// it is worth opening.
  Map<NutrientCategory, int> _countsFor(Map<NutrientId, double> totals) {
    final counts = <NutrientCategory, int>{};
    for (final nutrient in _catalog.values) {
      final intake = totals[nutrient.id] ?? 0;
      final target = _targets[nutrient.id] ?? 0;
      if (intake > 0 || target > 0) {
        counts[nutrient.category] = (counts[nutrient.category] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Per-day totals of the selected nutrient across the visible range.
  Map<DateTime, double> get _trendTotals {
    final nutrient = _selectedNutrient;
    if (nutrient == null) return {};
    final totals = <DateTime, double>{};
    for (final entry in _rangeEntries) {
      final day = DateTime.tryParse(entry.entryDate);
      if (day == null) continue;
      final key = DateTime(day.year, day.month, day.day);
      totals[key] = (totals[key] ?? 0) + entry.nutrient(nutrient);
    }
    return totals;
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: const Text('Nutrição'),
        actions: [
          IconButton(
            onPressed: _openLibrary,
            icon: const Icon(Icons.library_books_outlined),
            tooltip: 'Receitas e pacotes',
          ),
          IconButton(
            onPressed: _openTargets,
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Metas diárias',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange))
            : SupabaseService.currentUser == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Entre na sua conta para registrar refeições.',
                        textAlign: TextAlign.center,
                        style: AppTheme.caption
                            .copyWith(fontWeight: FontWeight.w400),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                    children: [
                      _buildDailyCard(),
                      if (_selectedNutrient != null) ...[
                        const SizedBox(height: 20),
                        _buildTrendCard(),
                      ],
                      const SizedBox(height: 20),
                      _buildEntryList(),
                      const SizedBox(height: 20),
                      _buildWeightHistoryCard(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDailyCard() {
    // One pass over the day's entries feeds the rows, the chip counts and
    // the headline figure.
    final totals = calculateTotals(_dayEntries);
    final rows = _rowsFor(totals);
    final categories = _categories;
    final counts = _countsFor(totals);
    final kcal = totals[NutrientId.calories] ?? 0;
    final kcalTarget = _targets[NutrientId.calories];
    final trackedTotal = counts.values.fold<int>(0, (sum, c) => sum + c);

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
                onPressed: () => _changeDay(-1),
                icon: const Icon(Icons.chevron_left),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Dia anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${kWeekdaysShort[_day.weekday - 1]} '
                    '${formatDayMonth(_day)}',
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isAtToday ? null : () => _changeDay(1),
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.mediumBrown,
                visualDensity: VisualDensity.compact,
                tooltip: 'Próximo dia',
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${kcal.round()}', style: AppTheme.headingLarge),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  kcalTarget != null
                      ? 'de ${kcalTarget.round()} kcal'
                      : 'kcal',
                  style: AppTheme.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Wrapped rather than a horizontal scroller: every group has to
          // be visible at a glance, which is the whole point of showing
          // them all.
          if (categories.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  _buildCategoryChip(category, counts[category] ?? 0),
              ],
            ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  // "Nothing in this group" and "nothing all day" are very
                  // different situations now that every group is offered.
                  trackedTotal == 0
                      ? 'Nada registrado neste dia.\n'
                          'Toque em + para adicionar um alimento.'
                      : 'Nenhum valor de '
                          '${(kNutrientCategoryLabels[_category] ?? '').toLowerCase()} '
                          'neste dia.\nOs alimentos registrados não trazem '
                          'esses componentes, ou eles são zero.',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final height = _NutrientBarChartPainter.axisHeight +
                    rows.length * _NutrientBarChartPainter.rowHeight;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _selectRow(details, rows),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, height),
                    painter: _NutrientBarChartPainter(
                      rows: rows,
                      selected: _selectedNutrient,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 6),
          Text(
            'Toque em um nutriente para ver a evolução.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  void _selectRow(TapDownDetails details, List<_NutrientRow> rows) {
    final y = details.localPosition.dy -
        _NutrientBarChartPainter.axisHeight;
    if (y < 0) return;
    final index = (y / _NutrientBarChartPainter.rowHeight).floor();
    if (index < 0 || index >= rows.length) return;
    final id = rows[index].nutrient.id;
    setState(() {
      _selectedNutrient = _selectedNutrient == id ? null : id;
      _selectedTrendDay = null;
    });
  }

  /// [count] is how many nutrients the group would show; an empty group
  /// stays tappable but reads as muted so it doesn't invite a dead end.
  Widget _buildCategoryChip(NutrientCategory category, int count) {
    final isSelected = category == _category;
    final isEmpty = count == 0;

    final Color background;
    final Color foreground;
    if (isSelected) {
      background = isEmpty
          ? AppTheme.mediumBrown.withValues(alpha: 0.35)
          : AppTheme.primaryOrange;
      foreground = Colors.white;
    } else if (isEmpty) {
      background = AppTheme.mediumBrown.withValues(alpha: 0.08);
      foreground = AppTheme.mediumBrown.withValues(alpha: 0.6);
    } else {
      background = AppTheme.primaryOrange.withValues(alpha: 0.1);
      foreground = AppTheme.primaryOrange;
    }

    return GestureDetector(
      onTap: () => setState(() {
        _category = category;
        _selectedNutrient = null;
      }),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
        ),
        child: Text(
          isEmpty
              ? (kNutrientCategoryLabels[category] ?? category.name)
              : '${kNutrientCategoryLabels[category] ?? category.name} · $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    final nutrient = _catalog[_selectedNutrient];
    if (nutrient == null) return const SizedBox.shrink();

    final days = _rangeDaysList;
    final totals = _trendTotals;
    // For calories, an estimated goal from the body-profile form (RMR +
    // activity + exercise + TEF, adjusted for the stated goal/rate) takes
    // over from the manually-set recommendation, once there's enough
    // profile data to compute one. Every other nutrient keeps the manual
    // target as before.
    final isCalories = nutrient.id == NutrientId.calories;
    final energyEstimate = isCalories ? _energyEstimate : null;
    final target = energyEstimate?.goalCalories ?? _targets[nutrient.id];
    // The projection below has to compare intake against true maintenance
    // (TDEE), not the goal-adjusted target - otherwise a deliberate
    // deficit/surplus baked into the goal would cancel itself out of the
    // predicted weight change.
    final maintenanceCalories = energyEstimate?.tdee ?? target;
    final logged =
        days.where((d) => (totals[d] ?? 0) > 0).length;
    final sum = days.fold<double>(0, (s, d) => s + (totals[d] ?? 0));
    final average = logged > 0 ? sum / logged : 0.0;

    final selectedDay = _selectedTrendDay;

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
              Expanded(
                child: Text(nutrient.name,
                    style: AppTheme.sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              SegmentedButton<_TrendRange>(
                segments: const [
                  ButtonSegment(value: _TrendRange.day, label: Text('Dia')),
                  ButtonSegment(
                      value: _TrendRange.week, label: Text('Semana')),
                  ButtonSegment(value: _TrendRange.month, label: Text('Mês')),
                ],
                selected: {_trendRange},
                onSelectionChanged: (s) {
                  setState(() {
                    _trendRange = s.first;
                    _selectedTrendDay = null;
                    _isLoading = true;
                  });
                  _load();
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  foregroundColor: AppTheme.mediumBrown,
                  selectedBackgroundColor:
                      AppTheme.primaryOrange.withValues(alpha: 0.15),
                  selectedForegroundColor: AppTheme.primaryOrange,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: AppTheme.borderOrange),
                ),
              ),
            ],
          ),
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
                    days.first == days.last
                        ? formatDayMonth(days.first)
                        : '${formatDayMonth(days.first)} – '
                            '${formatDayMonth(days.last)}',
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
              _buildStat(
                selectedDay != null
                    ? formatDayMonth(selectedDay)
                    : 'Média por dia',
                selectedDay != null
                    ? '${formatNutrientAmount(totals[selectedDay] ?? 0)} '
                        '${nutrient.unitLabel}'
                    : logged > 0
                        ? '${formatNutrientAmount(average)} '
                            '${nutrient.unitLabel}'
                        : '—',
              ),
              const SizedBox(width: 24),
              _buildStat(
                'Meta',
                target != null
                    ? '${formatNutrientAmount(target)} '
                        '${nutrient.unitLabel}'
                    : '—',
                trailing: energyEstimate != null
                    ? GestureDetector(
                        onTap: () => _showEnergyBreakdown(energyEstimate),
                        child: const Icon(Icons.info_outline,
                            size: 14, color: AppTheme.primaryOrange),
                      )
                    : null,
              ),
              const SizedBox(width: 24),
              _buildStat(
                '% Meta',
                () {
                  final value =
                      selectedDay != null ? (totals[selectedDay] ?? 0) : average;
                  final hasValue = selectedDay != null || logged > 0;
                  if (target == null || target <= 0 || !hasValue) return '—';
                  return '${(value / target * 100).round()}%';
                }(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _selectTrendDay(
                    d.localPosition, constraints.maxWidth, days),
                onHorizontalDragUpdate: (d) => _selectTrendDay(
                    d.localPosition, constraints.maxWidth, days),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 160),
                  painter: _NutrientTrendPainter(
                    days: days,
                    values: totals,
                    target: target,
                    weekView: _trendRange != _TrendRange.month,
                    selectedDay: selectedDay,
                  ),
                ),
              );
            },
          ),
          if (isCalories &&
              maintenanceCalories != null &&
              maintenanceCalories > 0 &&
              logged > 0)
            _buildProjectionCard(average - maintenanceCalories),
        ],
      ),
    );
  }

  /// Weight-change projection: at ~7700 kcal per kg of body fat, a daily
  /// surplus or deficit held for a while adds up to a certain number of
  /// kg. Only makes sense for calories, and only once there's an average
  /// and a target to compare it against - both already guaranteed by the
  /// caller.
  static const double _kcalPerKg = 7700;

  static const _projectionPeriods = [
    (label: '2 meses', days: 61),
    (label: '6 meses', days: 182),
    (label: '2 anos', days: 730),
  ];

  Widget _buildProjectionCard(double dailyDiff) {
    final weight = _weightKg;
    final height = _heightCm;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.creamBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mantendo essa média, projeção de peso '
            '(≈${_kcalPerKg.round()} kcal/kg):',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final period in _projectionPeriods)
                Expanded(
                  child: _buildProjectionStat(
                      period.label, dailyDiff, period.days),
                ),
            ],
          ),
          if (weight != null) ...[
            const SizedBox(height: 16),
            Text('Peso previsto',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final period in _projectionPeriods)
                  Expanded(
                    child: _buildWeightStat(
                        period.label, weight, dailyDiff, period.days),
                  ),
              ],
            ),
          ],
          if (weight != null && height != null && height > 0) ...[
            const SizedBox(height: 16),
            Text('IMC previsto',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final period in _projectionPeriods)
                  Expanded(
                    child: _buildBmiStat(period.label, weight, height,
                        dailyDiff, period.days),
                  ),
              ],
            ),
          ],
          if (weight == null || height == null || height <= 0) ...[
            const SizedBox(height: 10),
            Text(
              'Informe altura e peso no seu perfil para ver o peso e o '
              'IMC previstos.',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectionStat(String label, double dailyDiff, int days) {
    final kg = dailyDiff * days / _kcalPerKg;
    final sign = kg > 0.05 ? '+' : '';
    final color = kg > 0.05
        ? AppTheme.primaryOrange
        : kg < -0.05
            ? const Color(0xFF81C784)
            : AppTheme.mediumBrown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 2),
        Text('$sign${formatNutrientAmount(kg)} kg',
            style: AppTheme.valueBold.copyWith(color: color)),
      ],
    );
  }

  Widget _buildWeightStat(
      String label, double weight, double dailyDiff, int days) {
    final projected = weight + dailyDiff * days / _kcalPerKg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 2),
        Text('${formatNutrientAmount(projected)} kg',
            style: AppTheme.valueBold),
      ],
    );
  }

  Widget _buildBmiStat(String label, double weight, double heightCm,
      double dailyDiff, int days) {
    final projectedWeight = weight + dailyDiff * days / _kcalPerKg;
    final heightM = heightCm / 100;
    final bmi = projectedWeight / (heightM * heightM);
    final classification = _classifyBmi(bmi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 2),
        Text(formatNutrientAmount(bmi),
            style: AppTheme.valueBold
                .copyWith(color: classification.$2)),
        Text(classification.$1,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.caption.copyWith(
                color: classification.$2, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// WHO adult BMI bands. Same orange used for both "abaixo do peso" and
  /// "sobrepeso" - both read as "not the target band" - with green
  /// reserved for the ideal range and red shades for the obesity classes.
  (String, Color) _classifyBmi(double bmi) {
    if (bmi < 18.5) return ('Abaixo do peso', AppTheme.primaryOrange);
    if (bmi < 25) return ('Peso ideal', const Color(0xFF81C784));
    if (bmi < 30) return ('Sobrepeso', AppTheme.primaryOrange);
    if (bmi < 35) return ('Obesidade grau I', Colors.red.shade400);
    if (bmi < 40) return ('Obesidade grau II', Colors.red.shade600);
    return ('Obesidade grau III', Colors.red.shade800);
  }

  void _selectTrendDay(
      Offset position, double width, List<DateTime> days) {
    const left = _NutrientTrendPainter.leftLabelWidth;
    final plotWidth = width - left - 4;
    if (plotWidth <= 0) return;
    final index =
        ((position.dx - left) / (plotWidth / days.length)).floor();
    if (index < 0 || index >= days.length) return;
    final day = days[index];
    if (day != _selectedTrendDay) {
      setState(() => _selectedTrendDay = day);
    }
  }

  Widget _buildStat(String label, String value, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTheme.caption),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.valueBold),
      ],
    );
  }

  /// Bottom sheet with the full RMR -> TDEE -> goal-calories breakdown,
  /// opened from the info icon next to "Meta" once it's computed.
  void _showEnergyBreakdown(EnergyEstimate estimate) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => _EnergyBreakdownSheet(estimate: estimate),
    );
  }

  Widget _buildEntryList() {
    final entries = _dayEntries;

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
          const Text('Alimentos do dia', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum alimento registrado.',
                  style: AppTheme.caption
                      .copyWith(fontWeight: FontWeight.w400)),
            ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusTiny),
                      onTap: () => _showCalorieEquivalent(entry),
                      child: Row(
                        children: [
                          // A recipe and a package look nothing alike
                          // once logged - both end up as "name +
                          // weight" - so the icon is what says where a
                          // row came from.
                          if (entry.recipe != null || entry.package != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                entry.recipe != null
                                    ? Icons.menu_book_outlined
                                    : Icons.inventory_2_outlined,
                                size: 16,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.food.label,
                                    style: AppTheme.bodyText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  '${entry.amountLabel} · '
                                  '${entry.nutrient(NutrientId.calories).round()} kcal',
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteEntry(entry),
                    icon: Icon(Icons.close,
                        size: 18,
                        color: AppTheme.mediumBrown
                            .withValues(alpha: 0.6)),
                    tooltip: 'Excluir',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Monday at midnight of the week [d] falls in - the bucket key for the
  /// weekly-average chart.
  DateTime _weekStart(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// One average per week that has at least one check-in; weeks with none
  /// are simply absent rather than interpolated or shown as zero.
  List<MapEntry<DateTime, double>> get _weeklyWeightAverages {
    final sums = <DateTime, double>{};
    final counts = <DateTime, int>{};
    for (final entry in _weightHistory) {
      final week = _weekStart(entry.recordedAt);
      sums[week] = (sums[week] ?? 0) + entry.weightKg;
      counts[week] = (counts[week] ?? 0) + 1;
    }
    final averages = [
      for (final week in sums.keys) MapEntry(week, sums[week]! / counts[week]!),
    ];
    averages.sort((a, b) => a.key.compareTo(b.key));
    return averages;
  }

  Widget _buildWeightHistoryCard() {
    final weekCutoff = DateTime.now().subtract(const Duration(days: 7));
    final weekPoints = _weightHistory
        .where((e) => e.recordedAt.isAfter(weekCutoff))
        .map((e) => MapEntry(e.recordedAt, e.weightKg))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final monthPoints = _weeklyWeightAverages;

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
          const Text('Peso corporal', style: AppTheme.sectionTitle),
          if (_weightHistory.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nenhum peso registrado ainda. Informe seu peso no perfil '
              'para acompanhar aqui.',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text('Esta semana',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildWeightChart(weekPoints, weekView: true),
            const SizedBox(height: 20),
            Text('Últimos meses (média semanal)',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildWeightChart(monthPoints, weekView: false),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightChart(List<MapEntry<DateTime, double>> points,
      {required bool weekView}) {
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            weekView
                ? 'Nenhum peso registrado nos últimos 7 dias.'
                : 'Ainda não há semanas com peso registrado.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, 140),
        painter: _WeightLinePainter(
          points: points,
          labelForX: weekView
              ? (d) => kWeekdaysShort[d.weekday - 1]
              : formatDayMonth,
        ),
      ),
    );
  }
}

/// RMR -> NEAT -> exercise -> TEF -> TDEE -> goal calories, laid out as a
/// receipt. Every number here is a population-level approximation - the
/// disclaimer up top says so, since Mifflin-St Jeor (like every predictive
/// equation) has real individual error.
class _EnergyBreakdownSheet extends StatelessWidget {
  final EnergyEstimate estimate;

  const _EnergyBreakdownSheet({required this.estimate});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimativa de gasto calórico',
                  style: AppTheme.headingMedium),
              const SizedBox(height: 4),
              Text(
                'Baseada na fórmula de Mifflin-St Jeor e nos dados do seu '
                'perfil. É uma aproximação - a taxa metabólica real varia '
                'de pessoa para pessoa.',
                style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 20),
              _row('Taxa metabólica basal (RMR)', estimate.rmr),
              _row('Atividade não-exercício (NEAT)', estimate.neat),
              _row('Musculação', estimate.weightlifting),
              _row('Cardio', estimate.cardio),
              _row('Efeito térmico dos alimentos (TEF)', estimate.tef),
              const Divider(height: 24),
              _row('Manutenção estimada (TDEE)', estimate.tdee, bold: true),
              const SizedBox(height: 8),
              Text(
                'Faixa prática: ${estimate.rangeLow.round()}–'
                '${estimate.rangeHigh.round()} kcal',
                style: AppTheme.caption,
              ),
              if (estimate.trainingDaysPerWeek > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Dia de treino (${estimate.trainingDaysPerWeek}x/semana): '
                  '${estimate.trainingDayCalories.round()} kcal · '
                  'Dia de descanso: ${estimate.restDayCalories.round()} kcal',
                  style: AppTheme.caption,
                ),
              ],
              const SizedBox(height: 24),
              Text('Calorias por objetivo', style: AppTheme.sectionTitle),
              const SizedBox(height: 8),
              _goalRow('Manter', estimate.goalOptions['maintain']!),
              _goalRow(
                  'Perder 0,25 kg/semana', estimate.goalOptions['lose_slow']!),
              _goalRow('Perder 0,5 kg/semana',
                  estimate.goalOptions['lose_moderate']!),
              _goalRow(
                  'Perder 0,75 kg/semana', estimate.goalOptions['lose_fast']!),
              _goalRow(
                  'Ganhar 0,25 kg/semana', estimate.goalOptions['gain_slow']!),
              _goalRow('Ganhar 0,5 kg/semana',
                  estimate.goalOptions['gain_moderate']!),
              _goalRow(
                  'Ganhar 0,75 kg/semana', estimate.goalOptions['gain_fast']!),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar',
                      style: TextStyle(color: AppTheme.primaryOrange)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: bold
                    ? AppTheme.valueBold
                    : AppTheme.bodyText.copyWith(fontWeight: FontWeight.w400)),
          ),
          Text('${value.round()} kcal',
              style: bold
                  ? AppTheme.valueBold
                  : AppTheme.bodyText.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _goalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.caption)),
          Text('${value.round()} kcal',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// One unit of a healthy reference food, for the "what else could this be"
/// easter egg on the entry list. Amounts are rough, well-known portions
/// (a whole egg, a slice of watermelon, a handful of nuts) rather than
/// precise weights - the point is a fun comparison, not a diet plan.
class _HealthyFoodRef {
  final String singular;
  final String plural;
  final double kcal;

  const _HealthyFoodRef(this.singular, this.plural, this.kcal);
}

/// Fruits, vegetables, legumes and the like, each with an approximate
/// calorie count per common portion (based on typical Brazilian food
/// composition figures, e.g. TACO).
const List<_HealthyFoodRef> _healthyFoodRefs = [
  // 🍓 Fruits
  _HealthyFoodRef('banana', 'bananas', 90),
  _HealthyFoodRef('maçã', 'maçãs', 78),
  _HealthyFoodRef('laranja', 'laranjas', 65),
  _HealthyFoodRef('pera', 'peras', 70),
  _HealthyFoodRef('manga', 'mangas', 100),
  _HealthyFoodRef('kiwi', 'kiwis', 42),
  _HealthyFoodRef('pêssego', 'pêssegos', 51),
  _HealthyFoodRef('abacaxi', 'abacaxis', 42),
  _HealthyFoodRef('uva (1 punhado)', 'uvas (1 punhado)', 53),
  _HealthyFoodRef('morango (1 xícara)', 'morangos (1 xícara)', 48),
  _HealthyFoodRef('melancia (1 fatia)', 'fatias de melancia', 90),
  _HealthyFoodRef('melão (1 fatia)', 'fatias de melão', 60),
  _HealthyFoodRef('goiaba', 'goiabas', 55),
  _HealthyFoodRef('tangerina', 'tangerinas', 50),
  _HealthyFoodRef('ameixa', 'ameixas', 30),
  _HealthyFoodRef('carambola', 'carambolas', 25),
  _HealthyFoodRef('mamão (1 fatia)', 'fatias de mamão', 40),
  _HealthyFoodRef('maracujá', 'maracujás', 50),
  _HealthyFoodRef('pitaya', 'pitayas', 60),

  // 🥦 Vegetables
  _HealthyFoodRef('tomate', 'tomates', 20),
  _HealthyFoodRef('pepino', 'pepinos', 25),
  _HealthyFoodRef('cenoura', 'cenouras', 25),
  _HealthyFoodRef('alface (1 folha)', 'folhas de alface', 2),
  _HealthyFoodRef('rúcula (1 punhado)', 'punhados de rúcula', 5),
  _HealthyFoodRef('couve (1 folha)', 'folhas de couve', 10),
  _HealthyFoodRef('espinafre (1 punhado)', 'punhados de espinafre', 7),
  _HealthyFoodRef('abobrinha', 'abobrinhas', 35),
  _HealthyFoodRef('chuchu', 'chuchus', 35),
  _HealthyFoodRef('berinjela', 'berinjelas', 70),
  _HealthyFoodRef('brócolis (1 ramo)', 'ramos de brócolis', 15),
  _HealthyFoodRef('couve-flor (1 ramo)', 'ramos de couve-flor', 10),
  _HealthyFoodRef('vagem (1 punhado)', 'punhados de vagem', 30),
  _HealthyFoodRef('pimentão', 'pimentões', 25),
  _HealthyFoodRef('cebola', 'cebolas', 45),
  _HealthyFoodRef('repolho (1 pedaço)', 'pedaços de repolho', 20),
  _HealthyFoodRef('abóbora (1 pedaço)', 'pedaços de abóbora', 40),
  _HealthyFoodRef('quiabo', 'quiabos', 10),
  _HealthyFoodRef('palmito (1 unidade)', 'unidades de palmito', 15),

  // 🥔 Roots and tubers
  _HealthyFoodRef('inhame cozido (100 g)', 'porções de inhame cozido', 97),
  _HealthyFoodRef('batata-doce cozida (100 g)',
      'porções de batata-doce cozida', 77),
  _HealthyFoodRef('batata cozida', 'batatas cozidas', 97),
  _HealthyFoodRef('mandioca cozida (100 g)',
      'porções de mandioca cozida', 125),
  _HealthyFoodRef('mandioquinha cozida (100 g)',
      'porções de mandioquinha cozida', 80),

  // 🫘 Legumes and grains-like foods
  _HealthyFoodRef('feijão (1 concha)', 'conchas de feijão', 77),
  _HealthyFoodRef('lentilha (100 g)', 'porções de lentilha', 115),
  _HealthyFoodRef('grão-de-bico (100 g)', 'porções de grão-de-bico', 160),
  _HealthyFoodRef('ervilha (100 g)', 'porções de ervilha', 80),

  // 🥚 Other nutritious foods
  _HealthyFoodRef('ovo cozido', 'ovos cozidos', 74),
  _HealthyFoodRef('amêndoas (10 unidades)', 'porções de amêndoas', 70),
  _HealthyFoodRef('castanha-do-pará (2 unidades)',
      'porções de castanha-do-pará', 65),
  _HealthyFoodRef('abacate', 'abacates', 320),
];

/// One line of the daily chart.
class _NutrientRow {
  final Nutrient nutrient;
  final double intake;

  /// Null when the active recommendation set says nothing about it.
  final double? target;

  const _NutrientRow({
    required this.nutrient,
    required this.intake,
    this.target,
  });

  double get fraction =>
      target == null || target! <= 0 ? 0 : intake / target!;
}

// ---------------------------------------------------------------------------
// Entry sheets
// ---------------------------------------------------------------------------

enum _EntryKind { ingredient, package, recipe, manage }

/// What the + button opens: which of the three shapes of a meal is being
/// logged, plus a way into the screen that defines the last two.
class _EntryKindSheet extends StatelessWidget {
  const _EntryKindSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O que você comeu?', style: AppTheme.headingMedium),
            const SizedBox(height: 12),
            _buildOption(
              context,
              kind: _EntryKind.ingredient,
              icon: Icons.grain,
              title: 'Ingrediente',
              subtitle: 'Um alimento do catálogo, pesado em '
                  'gramas ou ml',
            ),
            _buildOption(
              context,
              kind: _EntryKind.package,
              icon: Icons.inventory_2_outlined,
              title: 'Pacote',
              subtitle: 'Um alimento em tamanho fixo - o pacote '
                  'inteiro, sem pesar',
            ),
            _buildOption(
              context,
              kind: _EntryKind.recipe,
              icon: Icons.menu_book_outlined,
              title: 'Receita',
              subtitle: 'Vários ingredientes num prato só',
            ),
            const Divider(height: 24),
            _buildOption(
              context,
              kind: _EntryKind.manage,
              icon: Icons.library_books_outlined,
              title: 'Gerenciar receitas e pacotes',
              subtitle: 'Criar ou editar, usando os alimentos que '
                  'você já tem',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required _EntryKind kind,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        onTap: () => Navigator.pop(context, kind),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child:
                    Icon(icon, size: 20, color: AppTheme.primaryOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.valueBold),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTheme.caption
                            .copyWith(fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One selectable line of [_EntrySheet], plus what saving it does.
///
/// The three kinds of entry only differ in what one unit of the typed
/// amount means - a gram of an ingredient, a whole pack, a gram of a
/// finished dish - so the sheet itself doesn't know which it is showing.
class _LogOption {
  final String title;
  final String subtitle;

  /// Label of the amount field: "Quantidade" reads right for packs,
  /// while grams are just an amount.
  final String amountLabel;

  /// Suffix of the amount field: 'g', 'ml' or 'un'.
  final String unitSuffix;
  final double defaultAmount;

  /// Calories in one unit of the amount field, for the live preview.
  final double kcalPerUnit;

  /// Writes the log row for [amount] units.
  final Future<void> Function(String entryDate, double amount) save;

  const _LogOption({
    required this.title,
    required this.subtitle,
    this.amountLabel = 'Quantidade',
    required this.unitSuffix,
    required this.defaultAmount,
    required this.kcalPerUnit,
    required this.save,
  });
}

/// Search, pick one, type how much of it was eaten. Pops `true` after a
/// successful save.
class _EntrySheet extends StatefulWidget {
  final String title;
  final List<_LogOption> options;
  final String entryDate;

  const _EntrySheet({
    required this.title,
    required this.options,
    required this.entryDate,
  });

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final TextEditingController _amountController =
      TextEditingController();
  String _query = '';
  _LogOption? _selected;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final option = _selected;
    final amount = _amount;
    if (option == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escolha um item e uma quantidade.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await option.save(widget.entryDate, amount);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.options.take(30).toList()
        : widget.options
            .where((o) => o.title.toLowerCase().contains(query))
            .toList();
    final selected = _selected;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTheme.headingMedium),
          const SizedBox(height: 16),
          if (selected == null) ...[
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar',
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.mediumBrown),
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Nada encontrado.',
                          style: AppTheme.caption
                              .copyWith(fontWeight: FontWeight.w400)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final option = matches[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(option.title,
                              style: AppTheme.bodyText),
                          subtitle: Text(option.subtitle,
                              style: AppTheme.caption),
                          onTap: () => setState(() {
                            _selected = option;
                            _amountController.text =
                                formatQuantity(option.defaultAmount);
                          }),
                        );
                      },
                    ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(selected.title, style: AppTheme.valueBold),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected = null),
                  child: const Text('Trocar',
                      style: TextStyle(color: AppTheme.primaryOrange)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: selected.amountLabel,
                suffixText: selected.unitSuffix,
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryOrange, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _amount != null && _amount! > 0
                  ? '≈ ${(_amount! * selected.kcalPerUnit).round()} kcal'
                  : selected.subtitle,
              style: AppTheme.caption,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
                child: Text(_isSaving ? 'Salvando...' : 'Adicionar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart painters
// ---------------------------------------------------------------------------

/// One horizontal bar per nutrient, measured as a percentage of the
/// day's target. Percent is the only axis that can hold protein (g) and
/// B12 (µg) at the same time; nutrients with no target fall back to a
/// muted bar scaled against the largest intake in the group.
class _NutrientBarChartPainter extends CustomPainter {
  final List<_NutrientRow> rows;
  final NutrientId? selected;

  _NutrientBarChartPainter({required this.rows, this.selected});

  static const axisHeight = 22.0;
  static const rowHeight = 28.0;
  static const _rightLabelWidth = 60.0;

  /// Names run long once the full panel is reachable ("Vitamina B5 (ácido
  /// pantotênico)", "Ácido linoleico conjugado (CLA)"), so the label
  /// column scales with the card rather than sitting at a fixed width.
  /// Only paint() needs this - row hit-testing is purely vertical.
  static double labelWidthFor(double width) =>
      (width * 0.40).clamp(96.0, 160.0);
  static const _axisMaxPercent = 150.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = labelWidthFor(size.width);
    final plotWidth = size.width - plotLeft - _rightLabelWidth;
    if (plotWidth <= 0) return;

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    const marks = [0.0, 50.0, 100.0, 150.0];
    for (final mark in marks) {
      final x = plotLeft + plotWidth * mark / _axisMaxPercent;
      canvas.drawLine(
          Offset(x, axisHeight), Offset(x, size.height), gridPaint);
      _paintText(
        canvas,
        '${mark.round()}%',
        Offset(x, axisHeight / 2),
        anchorCenter: true,
        style: TextStyle(
          fontSize: 10,
          color: AppTheme.mediumBrown.withValues(alpha: 0.7),
        ),
      );
    }

    // Scale for rows the recommendation set says nothing about.
    final untargetedMax = rows
        .where((r) => r.target == null)
        .fold<double>(0, (m, r) => math.max(m, r.intake));

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final top = axisHeight + i * rowHeight;
      final center = top + rowHeight / 2;
      final isSelected = row.nutrient.id == selected;

      if (isSelected) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, rowHeight),
          Paint()..color = AppTheme.primaryOrange.withValues(alpha: 0.06),
        );
      }

      _paintText(
        canvas,
        row.nutrient.name,
        Offset(plotLeft - 8, center),
        anchorRight: true,
        maxWidth: plotLeft - 10,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.mediumBrown,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
      );

      final double barFraction;
      final Color barColor;
      if (row.target != null) {
        barFraction =
            (row.fraction * 100 / _axisMaxPercent).clamp(0.0, 1.0);
        barColor = switch (row.fraction) {
          < 0.9 => AppTheme.primaryOrange,
          <= 1.1 => const Color(0xFF81C784),
          _ => AppTheme.lightOrange,
        };
      } else {
        barFraction = untargetedMax > 0
            ? (row.intake / untargetedMax).clamp(0.0, 1.0)
            : 0.0;
        barColor = AppTheme.mediumBrown.withValues(alpha: 0.3);
      }

      const barHeight = 12.0;
      final right = plotLeft + plotWidth * barFraction;
      if (right > plotLeft) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              plotLeft,
              center - barHeight / 2,
              math.max(right, plotLeft + 2),
              center + barHeight / 2,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = barColor,
        );
      }

      // The true value, even when the bar was clamped at the axis edge.
      _paintText(
        canvas,
        '${formatNutrientAmount(row.intake)} '
        '${row.nutrient.unitLabel}',
        Offset(size.width, center),
        anchorRight: true,
        style: const TextStyle(
          fontSize: 10,
          color: AppTheme.mediumBrown,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset position, {
    required TextStyle style,
    bool anchorRight = false,
    bool anchorCenter = false,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    var offset =
        Offset(position.dx, position.dy - painter.height / 2);
    if (anchorRight) {
      offset = offset.translate(-painter.width, 0);
    } else if (anchorCenter) {
      offset = offset.translate(-painter.width / 2, 0);
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_NutrientBarChartPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.selected != selected;
  }
}

/// One vertical bar per day for a single nutrient, with a dashed line at
/// the daily target.
class _NutrientTrendPainter extends CustomPainter {
  final List<DateTime> days;
  final Map<DateTime, double> values;
  final double? target;
  final bool weekView;
  final DateTime? selectedDay;

  _NutrientTrendPainter({
    required this.days,
    required this.values,
    required this.target,
    required this.weekView,
    this.selectedDay,
  });

  static const leftLabelWidth = 40.0;
  static const _bottomAxisHeight = 18.0;

  /// Rounds an axis ceiling up to the next 1/2/5 x 10^n.
  static double _niceCeil(double value) {
    if (value <= 0) return 1;
    final magnitude =
        math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    for (final step in [1.0, 2.0, 5.0, 10.0]) {
      if (value <= step * magnitude) return step * magnitude;
    }
    return 10 * magnitude;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = leftLabelWidth;
    final plotWidth = size.width - plotLeft - 4;
    final plotBottom = size.height - _bottomAxisHeight;
    if (plotWidth <= 0 || plotBottom <= 0) return;

    var peak = 0.0;
    for (final day in days) {
      peak = math.max(peak, values[day] ?? 0);
    }
    if (target != null) peak = math.max(peak, target!);
    final yMax = _niceCeil(peak * 1.15);

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = plotBottom - plotBottom * fraction;
      canvas.drawLine(
          Offset(plotLeft, y), Offset(size.width, y), gridPaint);
      _paintText(
        canvas,
        formatNutrientAmount(yMax * fraction),
        Offset(plotLeft - 6, y),
        anchorRight: true,
        style: TextStyle(
          fontSize: 9,
          color: AppTheme.mediumBrown.withValues(alpha: 0.7),
        ),
      );
    }

    final slot = plotWidth / days.length;
    final barWidth = math.min(slot * 0.6, 18.0);
    final barPaint = Paint()..color = AppTheme.primaryOrange;
    final selectedPaint = Paint()..color = AppTheme.darkBrown;

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final value = values[day] ?? 0;
      final centerX = plotLeft + slot * i + slot / 2;

      if (value > 0) {
        final height = plotBottom * (value / yMax).clamp(0.0, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              centerX - barWidth / 2,
              plotBottom - math.max(height, 2),
              centerX + barWidth / 2,
              plotBottom,
            ),
            const Radius.circular(3),
          ),
          day == selectedDay ? selectedPaint : barPaint,
        );
      }

      // Week view labels every day; month view every fifth, or the
      // labels collide.
      final showLabel = weekView || i % 5 == 0 || i == days.length - 1;
      if (showLabel) {
        _paintText(
          canvas,
          weekView ? '${day.day}' : formatDayMonth(day),
          Offset(centerX, plotBottom + _bottomAxisHeight / 2),
          anchorCenter: true,
          style: TextStyle(
            fontSize: 9,
            color: day == selectedDay
                ? AppTheme.darkBrown
                : AppTheme.mediumBrown.withValues(alpha: 0.7),
            fontWeight: day == selectedDay
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        );
      }
    }

    if (target != null && target! > 0) {
      final y = plotBottom - plotBottom * (target! / yMax).clamp(0.0, 1.0);
      final dashPaint = Paint()
        ..color = AppTheme.darkBrown.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var x = plotLeft; x < size.width; x += 8) {
        canvas.drawLine(
            Offset(x, y), Offset(math.min(x + 4, size.width), y),
            dashPaint);
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
    var offset =
        Offset(position.dx, position.dy - painter.height / 2);
    if (anchorRight) {
      offset = offset.translate(-painter.width, 0);
    } else if (anchorCenter) {
      offset = offset.translate(-painter.width / 2, 0);
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_NutrientTrendPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.values != values ||
        oldDelegate.target != target ||
        oldDelegate.weekView != weekView ||
        oldDelegate.selectedDay != selectedDay;
  }
}

/// A simple connected-dot line for the body weight card - one series,
/// no target line, no day selection. [points] must be sorted ascending by
/// date and non-empty.
class _WeightLinePainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> points;
  final String Function(DateTime) labelForX;

  _WeightLinePainter({required this.points, required this.labelForX});

  static const _leftLabelWidth = 40.0;
  static const _bottomAxisHeight = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = _leftLabelWidth;
    final plotWidth = size.width - plotLeft - 4;
    final plotBottom = size.height - _bottomAxisHeight;
    if (plotWidth <= 0 || plotBottom <= 0) return;

    var minY = points.first.value;
    var maxY = points.first.value;
    for (final p in points) {
      minY = math.min(minY, p.value);
      maxY = math.max(maxY, p.value);
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    } else {
      final pad = (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }

    final gridPaint = Paint()
      ..color = AppTheme.mediumBrown.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = plotBottom - plotBottom * fraction;
      canvas.drawLine(
          Offset(plotLeft, y), Offset(size.width, y), gridPaint);
      _paintText(
        canvas,
        formatNutrientAmount(minY + (maxY - minY) * fraction),
        Offset(plotLeft - 6, y),
        anchorRight: true,
        style: TextStyle(
          fontSize: 9,
          color: AppTheme.mediumBrown.withValues(alpha: 0.7),
        ),
      );
    }

    double xFor(int i) => points.length == 1
        ? plotLeft + plotWidth / 2
        : plotLeft + plotWidth * i / (points.length - 1);
    double yFor(double value) => plotBottom -
        plotBottom * ((value - minY) / (maxY - minY)).clamp(0.0, 1.0);

    if (points.length > 1) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final offset = Offset(xFor(i), yFor(points[i].value));
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.primaryOrange
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    final dotPaint = Paint()..color = AppTheme.primaryOrange;
    // At most ~6 x-axis labels, evenly spread, always including the ends -
    // one per point would collide once a range has more than a handful.
    final labelEvery = math.max(1, (points.length / 6).ceil());
    for (var i = 0; i < points.length; i++) {
      final x = xFor(i);
      final y = yFor(points[i].value);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);

      final isLast = i == points.length - 1;
      if (i % labelEvery == 0 || isLast) {
        _paintText(
          canvas,
          labelForX(points[i].key),
          Offset(x, plotBottom + _bottomAxisHeight / 2),
          anchorCenter: true,
          style: TextStyle(
            fontSize: 9,
            color: AppTheme.mediumBrown.withValues(alpha: 0.7),
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
    var offset = Offset(position.dx, position.dy - painter.height / 2);
    if (anchorRight) {
      offset = offset.translate(-painter.width, 0);
    } else if (anchorCenter) {
      offset = offset.translate(-painter.width / 2, 0);
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_WeightLinePainter oldDelegate) =>
      oldDelegate.points != points;
}
