import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/food.dart';
import '../models/nutrient.dart';
import '../services/supabase_service.dart';
import '../widgets/food_picker_sheet.dart';
import 'food_recipe_editor_screen.dart';

/// Manages the two things that can be logged besides a plain ingredient:
/// recipes (several ingredients with their weights) and packages (one
/// ingredient in a fixed size).
///
/// Both are built out of foods that are already catalogued, so nothing
/// here ever asks for a nutrient value. Pops `true` when anything was
/// created, edited or deleted.
class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({super.key});

  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  bool _isLoading = true;
  List<Food> _foods = [];
  Map<String, Food> _foodsById = {};
  List<FoodRecipe> _recipes = [];
  List<FoodPackage> _packages = [];

  /// True once anything was written, so the nutrition screen reloads.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final catalogList = await SupabaseService.getNutrientCatalog();
      final catalog = {for (final n in catalogList) n.id: n};
      final foods = await SupabaseService.getFoods(catalog);
      final recipes = await SupabaseService.getFoodRecipes(catalog);
      final packages = await SupabaseService.getFoodPackages();
      if (!mounted) return;
      setState(() {
        _foods = foods;
        _foodsById = {for (final f in foods) f.id: f};
        _recipes = recipes;
        _packages = packages;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao carregar: $e')));
      }
    }
  }

  /// Shared rows (seeded in SQL, user_id null) and anything belonging to
  /// somebody else are read-only - RLS would refuse the write anyway.
  bool _isOwn(String? userId) =>
      userId != null && userId == SupabaseService.currentUser?.id;

  Future<void> _openRecipe([FoodRecipe? recipe]) async {
    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cadastre alimentos antes de montar receitas.')));
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FoodRecipeEditorScreen(foods: _foods, recipe: recipe),
      ),
    );
    if (saved != true || !mounted) return;
    _dirty = true;
    setState(() => _isLoading = true);
    await _load();
  }

  Future<void> _openPackage([FoodPackage? package]) async {
    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cadastre alimentos antes de criar pacotes.')));
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.creamBackground,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (_) => _PackageSheet(
        foods: _foods,
        package: package,
        food: package == null ? null : _foodsById[package.foodId],
      ),
    );
    if (saved != true || !mounted) return;
    _dirty = true;
    setState(() => _isLoading = true);
    await _load();
  }

  Future<void> _deletePackage(FoodPackage package) async {
    final food = _foodsById[package.foodId];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Excluir pacote', style: AppTheme.headingMedium),
        content: Text(
          'Excluir "${package.labelFor(food?.baseUnit ?? 'g')}" de '
          '${food?.label ?? 'este alimento'}? As refeições já '
          'registradas continuam valendo, com o peso em gramas.',
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
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService.deleteFoodPackage(package.id);
      _dirty = true;
      setState(() => _isLoading = true);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        backgroundColor: AppTheme.creamBackground,
        appBar: AppBar(
          title: const Text('Receitas e pacotes'),
          bottom: TabBar(
            controller: _tabs,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: AppTheme.mediumBrown,
            indicatorColor: AppTheme.primaryOrange,
            labelStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Receitas'),
              Tab(text: 'Pacotes'),
            ],
          ),
        ),
        floatingActionButton: _isLoading
            ? null
            : FloatingActionButton(
                onPressed: () =>
                    _tabs.index == 0 ? _openRecipe() : _openPackage(),
                tooltip: _tabs.index == 0 ? 'Nova receita' : 'Novo pacote',
                child: const Icon(Icons.add),
              ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryOrange))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildRecipeList(),
                    _buildPackageList(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRecipeList() {
    if (_recipes.isEmpty) {
      return _buildEmpty(
        'Nenhuma receita ainda.\nMonte uma com os alimentos que você '
        'já tem cadastrados e registre o prato inteiro de uma vez.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        for (final recipe in _recipes) _buildRecipeCard(recipe),
      ],
    );
  }

  Widget _buildRecipeCard(FoodRecipe recipe) {
    final weight = recipe.weight;
    final totalKcal = recipe.nutrients[NutrientId.calories]?.amount ?? 0;
    final per100 = weight > 0 ? totalKcal * 100 / weight : 0.0;
    final own = _isOwn(recipe.userId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: own ? () => _openRecipe(recipe) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(recipe.name,
                          style: AppTheme.sectionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (!own) _buildBadge('Modelo'),
                    if (own)
                      Icon(Icons.chevron_right,
                          size: 18,
                          color:
                              AppTheme.mediumBrown.withValues(alpha: 0.5)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${recipe.items.length} '
                  '${recipe.items.length == 1 ? 'ingrediente' : 'ingredientes'}'
                  ' · ${formatNutrientAmount(weight)} g · '
                  '${per100.round()} kcal por 100 g',
                  style: AppTheme.caption,
                ),
                if (recipe.items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    recipe.items.map((i) => i.food.name).join(', '),
                    style: AppTheme.caption
                        .copyWith(fontWeight: FontWeight.w400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Packages are grouped by their ingredient: the point of the tab is
  /// "which sizes do I have for this biscuit", not a flat list of weights.
  Widget _buildPackageList() {
    if (_packages.isEmpty) {
      return _buildEmpty(
        'Nenhum pacote ainda.\nUm pacote é um alimento com um peso '
        'fixo - o pacote pequeno e o grande de bolacha valem o mesmo '
        'por 100 g, só mudam de tamanho.',
      );
    }

    final byFood = <String, List<FoodPackage>>{};
    for (final package in _packages) {
      byFood.putIfAbsent(package.foodId, () => []).add(package);
    }
    final foodIds = byFood.keys.toList()
      ..sort((a, b) => (_foodsById[a]?.label ?? '')
          .compareTo(_foodsById[b]?.label ?? ''));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        for (final foodId in foodIds)
          _buildPackageGroup(_foodsById[foodId], byFood[foodId]!),
      ],
    );
  }

  Widget _buildPackageGroup(Food? food, List<FoodPackage> packages) {
    final unit = food?.baseUnit ?? 'g';
    packages.sort((a, b) => a.amount.compareTo(b.amount));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(food?.label ?? 'Alimento removido',
                style: AppTheme.sectionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            for (final package in packages)
              _buildPackageRow(food, package, unit),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageRow(Food? food, FoodPackage package, String unit) {
    final own = _isOwn(package.userId);
    final kcal = food == null || food.baseAmount <= 0
        ? null
        : food.get(NutrientId.calories) * package.amount / food.baseAmount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: own ? () => _openPackage(package) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.labelFor(unit), style: AppTheme.bodyText),
                    Text(
                      '${formatNutrientAmount(package.amount)} $unit'
                      '${kcal != null ? ' · ${kcal.round()} kcal' : ''}',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              if (!own)
                _buildBadge('Modelo')
              else
                IconButton(
                  onPressed: () => _deletePackage(package),
                  icon: Icon(Icons.close,
                      size: 18,
                      color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
                  tooltip: 'Excluir',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.mediumBrown.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.mediumBrown,
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Package sheet
// ---------------------------------------------------------------------------

/// Creates or edits one package: which ingredient, an optional name and
/// the weight one unit of it holds. Pops `true` after a save.
class _PackageSheet extends StatefulWidget {
  final List<Food> foods;

  /// Null when creating.
  final FoodPackage? package;

  /// The package's ingredient, already resolved by the caller.
  final Food? food;

  const _PackageSheet({
    required this.foods,
    this.package,
    this.food,
  });

  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.package?.name ?? '');
  // formatQuantity keeps the exact weight: formatNutrientAmount rounds
  // above 100, which would turn a 350.5 ml can into 351 ml on re-save.
  late final TextEditingController _amountController = TextEditingController(
    text: widget.package != null
        ? formatQuantity(widget.package!.amount)
        : '',
  );

  late Food? _food = widget.food;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickFood() async {
    final food = await showFoodPicker(context, widget.foods,
        title: 'Alimento do pacote');
    if (food == null || !mounted) return;
    setState(() => _food = food);
  }

  Future<void> _save() async {
    final food = _food;
    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (food == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escolha o alimento e o peso do pacote.')));
      return;
    }
    final name = _nameController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (widget.package == null) {
        await SupabaseService.createFoodPackage(
          foodId: food.id,
          name: name.isEmpty ? null : name,
          amount: amount,
        );
      } else {
        await SupabaseService.updateFoodPackage(
          widget.package!.id,
          foodId: food.id,
          name: name.isEmpty ? null : name,
          amount: amount,
        );
      }
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
    final food = _food;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.package == null ? 'Novo pacote' : 'Editar pacote',
              style: AppTheme.headingMedium),
          const SizedBox(height: 16),
          Material(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              onTap: _isSaving ? null : _pickFood,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alimento', style: AppTheme.caption),
                          const SizedBox(height: 2),
                          Text(
                            food?.label ?? 'Escolher',
                            style: food == null
                                ? AppTheme.bodyText
                                : AppTheme.valueBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: AppTheme.mediumBrown.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Nome (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration('Peso do pacote',
                suffix: food?.baseUnit ?? 'g'),
          ),
          const SizedBox(height: 8),
          Text(
            'Ex.: "Pacote pequeno", 140 g. Os nutrientes continuam vindo '
            'do alimento - o pacote só diz quanto vem em uma unidade.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
              child: Text(_isSaving ? 'Salvando...' : 'Salvar'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        borderSide:
            const BorderSide(color: AppTheme.primaryOrange, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
