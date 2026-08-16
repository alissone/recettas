import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/food.dart';
import '../models/nutrient.dart';
import '../services/supabase_service.dart';
import '../widgets/food_picker_sheet.dart';

/// Creates or edits one recipe: a name, its ingredients with weights,
/// and optionally how much the finished dish weighs.
///
/// Ingredients are always picked from the catalog, so a recipe's nutrient
/// values are derived and never typed. Pops `true` when something was
/// saved or deleted, so the caller knows to reload.
class FoodRecipeEditorScreen extends StatefulWidget {
  /// The catalog to pick ingredients from.
  final List<Food> foods;

  /// Null when creating a new recipe.
  final FoodRecipe? recipe;

  const FoodRecipeEditorScreen({
    super.key,
    required this.foods,
    this.recipe,
  });

  @override
  State<FoodRecipeEditorScreen> createState() =>
      _FoodRecipeEditorScreenState();
}

/// An ingredient line while it is being edited - the same pairing as
/// [FoodRecipeItem], minus the row id it doesn't have yet.
class _Ingredient {
  final Food food;
  double amount;

  _Ingredient(this.food, this.amount);
}

class _FoodRecipeEditorScreenState extends State<FoodRecipeEditorScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.recipe?.name ?? '');
  // formatQuantity, not formatNutrientAmount: the latter rounds anything
  // above 100, so re-saving a recipe would quietly move a 1250.5 g yield
  // to 1251 g.
  late final TextEditingController _yieldController = TextEditingController(
    text: widget.recipe?.hasYield == true
        ? formatQuantity(widget.recipe!.yieldAmount!)
        : '',
  );

  late final List<_Ingredient> _ingredients = [
    for (final item in widget.recipe?.items ?? const <FoodRecipeItem>[])
      _Ingredient(item.food, item.amount),
  ];

  bool _isSaving = false;

  bool get _isNew => widget.recipe == null;

  /// Everything that goes in, ml counted as g like everywhere else.
  double get _ingredientsAmount =>
      _ingredients.fold<double>(0, (sum, i) => sum + i.amount);

  /// What a portion will be measured against.
  double get _weight {
    final typed = _parseAmount(_yieldController.text);
    return typed != null && typed > 0 ? typed : _ingredientsAmount;
  }

  /// The recipe as it currently stands, so the summary can be built with
  /// the same code that will compute the logged entries.
  FoodRecipe get _preview => FoodRecipe(
        id: widget.recipe?.id ?? '',
        name: _nameController.text.trim(),
        yieldAmount: _parseAmount(_yieldController.text),
        items: [
          for (var i = 0; i < _ingredients.length; i++)
            FoodRecipeItem(
              id: '$i',
              food: _ingredients[i].food,
              amount: _ingredients[i].amount,
              sortOrder: i,
            ),
        ],
      );

  static double? _parseAmount(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _nameController.dispose();
    _yieldController.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final food = await showFoodPicker(
      context,
      widget.foods,
      disabledIds: {for (final i in _ingredients) i.food.id},
    );
    if (food == null || !mounted) return;
    final amount = await _promptAmount(food);
    if (amount == null || !mounted) return;
    setState(() => _ingredients.add(_Ingredient(food, amount)));
  }

  Future<void> _editIngredient(_Ingredient ingredient) async {
    final amount =
        await _promptAmount(ingredient.food, initial: ingredient.amount);
    if (amount == null || !mounted) return;
    setState(() => ingredient.amount = amount);
  }

  /// Returns the weight of one ingredient, or null if it was cancelled.
  Future<double?> _promptAmount(Food food, {double? initial}) async {
    final controller = TextEditingController(
      text: initial != null ? formatQuantity(initial) : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(food.label, style: AppTheme.headingMedium),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantidade na receita',
            suffixText: food.baseUnit,
            filled: true,
            fillColor: AppTheme.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.mediumBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    final amount = _parseAmount(result);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Informe uma quantidade válida.')));
      }
      return null;
    }
    return amount;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dê um nome à receita.')));
      return;
    }
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Adicione pelo menos um ingrediente.')));
      return;
    }
    final yieldText = _yieldController.text.trim();
    final yieldAmount = _parseAmount(yieldText);
    if (yieldText.isNotEmpty && (yieldAmount == null || yieldAmount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rendimento inválido. Deixe em branco para usar '
              'a soma dos ingredientes.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final items = [
        for (final ingredient in _ingredients)
          {'food_id': ingredient.food.id, 'amount': ingredient.amount},
      ];
      if (_isNew) {
        await SupabaseService.createFoodRecipe(
          name: name,
          yieldAmount: yieldAmount,
          items: items,
        );
      } else {
        await SupabaseService.updateFoodRecipe(
          widget.recipe!.id,
          name: name,
          yieldAmount: yieldAmount,
          items: items,
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

  Future<void> _delete() async {
    final recipe = widget.recipe;
    if (recipe == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Excluir receita', style: AppTheme.headingMedium),
        content: Text(
          'As refeições já registradas com "${recipe.name}" também '
          'somem do histórico. Excluir mesmo assim?',
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

    setState(() => _isSaving = true);
    try {
      await SupabaseService.deleteFoodRecipe(recipe.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao excluir: $e')));
      }
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: Text(_isNew ? 'Nova receita' : 'Editar receita'),
        actions: [
          if (!_isNew)
            IconButton(
              onPressed: _isSaving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir',
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _buildDetailsCard(),
            const SizedBox(height: 20),
            _buildIngredientsCard(),
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 24),
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
                child: Text(_isSaving ? 'Salvando...' : 'Salvar receita'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
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
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDecoration(label: 'Nome da receita'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _yieldController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(
              label: 'Rendimento (opcional)',
              suffix: 'g',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quanto pesa o prato pronto. Em branco, vale a soma dos '
            'ingredientes - preencha quando parte da água evapora no '
            'cozimento, para que 100 g do prato contem certo.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String label, String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: AppTheme.creamBackground,
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

  Widget _buildIngredientsCard() {
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
                child: Text('Ingredientes', style: AppTheme.sectionTitle),
              ),
              Text(
                _ingredients.isEmpty
                    ? ''
                    : '${formatNutrientAmount(_ingredientsAmount)} g',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhum ingrediente ainda. Eles vêm do catálogo de '
                'alimentos, então os nutrientes da receita saem prontos.',
                style:
                    AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
          for (final ingredient in _ingredients)
            _buildIngredientRow(ingredient),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _addIngredient,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar ingrediente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                side: BorderSide(color: AppTheme.borderOrange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(_Ingredient ingredient) {
    final kcal = ingredient.food.baseAmount <= 0
        ? 0.0
        : ingredient.food.get(NutrientId.calories) *
            ingredient.amount /
            ingredient.food.baseAmount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : () => _editIngredient(ingredient),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ingredient.food.label,
                        style: AppTheme.bodyText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${formatNutrientAmount(ingredient.amount)} '
                      '${ingredient.food.baseUnit} · ${kcal.round()} kcal',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _ingredients.remove(ingredient)),
                icon: Icon(Icons.close,
                    size: 18,
                    color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
                tooltip: 'Remover',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the recipe will contribute once it is logged, at the two scales
  /// that matter: the whole dish and the per-100 g figure used to compare
  /// it with anything else in the catalog.
  Widget _buildSummaryCard() {
    final preview = _preview;
    final weight = _weight;
    final totalKcal = preview.nutrients[NutrientId.calories]?.amount ?? 0;
    final per100 = weight > 0 ? totalKcal * 100 / weight : 0.0;

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
          const Text('Resultado', style: AppTheme.sectionTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStat('Peso final',
                  weight > 0 ? '${formatNutrientAmount(weight)} g' : '—'),
              const SizedBox(width: 24),
              _buildStat('Receita inteira',
                  weight > 0 ? '${totalKcal.round()} kcal' : '—'),
              const SizedBox(width: 24),
              _buildStat('Por 100 g',
                  weight > 0 ? '${per100.round()} kcal' : '—'),
            ],
          ),
          if (_ingredients.isNotEmpty && _weight < _ingredientsAmount) ...[
            const SizedBox(height: 10),
            Text(
              'O prato pronto pesa menos que os ingredientes: os '
              'nutrientes continuam os mesmos, só ficam mais '
              'concentrados por grama.',
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
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
}
