import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/food.dart';
import '../models/nutrient.dart';
import '../services/supabase_service.dart';
import '../utils/dates.dart';
import 'nutrient_targets_screen.dart';

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

  /// Static reference data, fetched once.
  Map<NutrientId, Nutrient> _catalog = {};
  List<Food> _foods = [];

  /// Daily targets from whichever set the profile points at. Which set
  /// that is - and what's in it - is owned by NutrientTargetsScreen.
  Map<NutrientId, double> _targets = {};

  /// Entries for the whole visible range; the day's list is filtered out
  /// of this so paging a day never costs a second request.
  List<FoodEntry> _rangeEntries = [];

  /// Last day of the visible range, and the day the totals are for.
  DateTime _day = today();
  bool _weekView = true;
  NutrientCategory _category = NutrientCategory.macronutrient;
  NutrientId? _selectedNutrient;
  DateTime? _selectedTrendDay;
  int _loadSeq = 0;

  int get _rangeDays => _weekView ? 7 : 30;

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
      final sets = await SupabaseService.getRecommendationSets();

      String? activeSetId;
      try {
        final profile = await SupabaseService.getProfile();
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

  Future<void> _addEntry() async {
    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Nenhum alimento cadastrado. Adicione-os no Supabase.')));
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) =>
          _FoodEntrySheet(foods: _foods, entryDate: isoDate(_day)),
    );
    if (saved == true) await _load();
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
    final target = _targets[nutrient.id];
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Semana')),
                  ButtonSegment(value: false, label: Text('Mês')),
                ],
                selected: {_weekView},
                onSelectionChanged: (s) {
                  setState(() {
                    _weekView = s.first;
                    _selectedTrendDay = null;
                    _isLoading = true;
                  });
                  _load();
                },
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
                    '${formatDayMonth(days.first)} – '
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
                    weekView: _weekView,
                    selectedDay: selectedDay,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
}

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
// Food sheet
// ---------------------------------------------------------------------------

/// Search the catalog, pick a food, type how much of it was eaten. Pops
/// `true` after a successful save.
class _FoodEntrySheet extends StatefulWidget {
  final List<Food> foods;
  final String entryDate;

  const _FoodEntrySheet({required this.foods, required this.entryDate});

  @override
  State<_FoodEntrySheet> createState() => _FoodEntrySheetState();
}

class _FoodEntrySheetState extends State<_FoodEntrySheet> {
  final TextEditingController _amountController =
      TextEditingController();
  String _query = '';
  Food? _selected;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final food = _selected;
    final amount = double.tryParse(
        _amountController.text.trim().replaceAll(',', '.'));
    if (food == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escolha um alimento e uma quantidade.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await SupabaseService.addFoodEntry(
        entryDate: widget.entryDate,
        foodId: food.id,
        amount: amount,
      );
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
        ? widget.foods.take(30).toList()
        : widget.foods
            .where((f) => f.label.toLowerCase().contains(query))
            .toList();
    final selected = _selected;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adicionar alimento', style: AppTheme.headingMedium),
          const SizedBox(height: 16),
          if (selected == null) ...[
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar alimento',
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
                      child: Text('Nenhum alimento encontrado.',
                          style: AppTheme.caption
                              .copyWith(fontWeight: FontWeight.w400)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final food = matches[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(food.label,
                              style: AppTheme.bodyText),
                          subtitle: Text(
                            '${food.get(NutrientId.calories).round()} kcal '
                            'por ${formatNutrientAmount(food.baseAmount)} '
                            '${food.baseUnit}',
                            style: AppTheme.caption,
                          ),
                          onTap: () => setState(() {
                            _selected = food;
                            _amountController.text =
                                formatNutrientAmount(food.baseAmount);
                          }),
                        );
                      },
                    ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(selected.label, style: AppTheme.valueBold),
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
              decoration: InputDecoration(
                labelText: 'Quantidade',
                suffixText: selected.baseUnit,
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
