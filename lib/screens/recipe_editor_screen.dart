import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/food.dart';
import '../models/nutrient.dart';
import '../models/recipe.dart';
import '../services/supabase_service.dart';
import '../widgets/food_picker_sheet.dart';

/// Creates or edits one recipe.
///
/// The ingredient list is the fixed part: rows picked from the food
/// catalog with a weight each, which is what lets the nutrition screen
/// log a plate of this. Everything after it is free-form - as many
/// sections as the cook wants, titled however they like.
///
/// Pops `true` when something was saved or deleted.
class RecipeEditorScreen extends StatefulWidget {
  /// The catalog to pick ingredients from.
  final List<Food> foods;

  /// Null when creating a new recipe.
  final Recipe? recipe;

  const RecipeEditorScreen({
    super.key,
    required this.foods,
    this.recipe,
  });

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

/// Asks for one ingredient's weight. Pops the parsed amount, or null
/// when cancelled.
///
/// The dialog owns its controller rather than taking one: disposing a
/// controller as soon as `showDialog` returns crashes, because the route
/// is still animating out and rebuilds the field - with a fresh merged
/// listenable each time - on the way. A State's dispose runs once the
/// route is actually gone.
class _AmountDialog extends StatefulWidget {
  final String title;

  /// The ingredient's own base unit: 'g' or 'ml'.
  final String unit;
  final double? initial;

  const _AmountDialog({
    required this.title,
    required this.unit,
    this.initial,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial != null ? formatQuantity(widget.initial!) : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Stays open on a bad number, so the typed text is still there to fix.
  void _submit() {
    final amount =
        double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe uma quantidade válida.');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Text(widget.title, style: AppTheme.headingMedium),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Quantidade na receita',
          suffixText: widget.unit,
          errorText: _error,
          filled: true,
          fillColor: AppTheme.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(color: AppTheme.mediumBrown)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// An ingredient line while it is being edited - the same pairing as
/// [RecipeIngredient], minus the row id it doesn't have yet.
class _Ingredient {
  final Food food;
  double amount;

  _Ingredient(this.food, this.amount);
}

/// A free-form section while it is being edited. Every line owns a
/// controller, so they have to be disposed as they are removed.
class _SectionDraft {
  final TextEditingController title;
  final List<TextEditingController> items;

  _SectionDraft({required this.title, required this.items});

  factory _SectionDraft.from(RecipeSection section) {
    return _SectionDraft(
      title: TextEditingController(text: section.title),
      items: [
        for (final item in section.items) TextEditingController(text: item),
      ],
    );
  }

  factory _SectionDraft.empty() {
    return _SectionDraft(
      title: TextEditingController(),
      items: [TextEditingController()],
    );
  }

  /// Blank lines are dropped rather than saved as empty bullets.
  RecipeSection toSection() {
    return RecipeSection(
      title: title.text.trim(),
      items: [
        for (final item in items)
          if (item.text.trim().isNotEmpty) item.text.trim(),
      ],
    );
  }

  bool get isEmpty =>
      title.text.trim().isEmpty &&
      items.every((i) => i.text.trim().isEmpty);

  void dispose() {
    title.dispose();
    for (final item in items) {
      item.dispose();
    }
  }
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.recipe?.name ?? '');
  late final TextEditingController _imageController =
      TextEditingController(text: widget.recipe?.image ?? '');
  late final TextEditingController _prepController =
      TextEditingController(text: widget.recipe?.prepTime ?? '');
  late final TextEditingController _totalController =
      TextEditingController(text: widget.recipe?.totalTime ?? '');

  // formatQuantity, not formatNutrientAmount: the latter rounds anything
  // above 100, so re-saving a recipe would quietly move a 1250.5 g yield
  // to 1251 g.
  late final TextEditingController _yieldController = TextEditingController(
    text: widget.recipe?.hasYield == true
        ? formatQuantity(widget.recipe!.yieldAmount!)
        : '',
  );

  /// The catalog to pick from. Starts as what the caller loaded and is
  /// replaced by the picker's reload button.
  late List<Food> _foods = widget.foods;

  late final List<_Ingredient> _ingredients = [
    for (final ingredient
        in widget.recipe?.ingredients ?? const <RecipeIngredient>[])
      _Ingredient(ingredient.food, ingredient.amount),
  ];

  late final List<_SectionDraft> _sections = [
    for (final section
        in widget.recipe?.sections ?? const <RecipeSection>[])
      _SectionDraft.from(section),
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

  /// The recipe as it currently stands, so the summary is built by the
  /// same code that will score the logged entries.
  Recipe get _preview => Recipe(
        id: widget.recipe?.id ?? '',
        name: _nameController.text.trim(),
        yieldAmount: _parseAmount(_yieldController.text),
        ingredients: [
          for (var i = 0; i < _ingredients.length; i++)
            RecipeIngredient(
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
    _imageController.dispose();
    _prepController.dispose();
    _totalController.dispose();
    _yieldController.dispose();
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  // --- Ingredients ---

  Future<void> _addIngredient() async {
    final food = await showFoodPicker(
      context,
      _foods,
      disabledIds: {for (final i in _ingredients) i.food.id},
      onReload: _reloadFoods,
    );
    if (food == null || !mounted) return;
    final amount = await _promptAmount(food);
    if (amount == null || !mounted) return;
    setState(() => _ingredients.add(_Ingredient(food, amount)));
  }

  /// Re-reads the food catalog, so an ingredient added in Supabase while
  /// the recipe was being written can be used without losing the work in
  /// progress.
  Future<List<Food>> _reloadFoods() async {
    final catalogList = await SupabaseService.getNutrientCatalog();
    final catalog = {for (final n in catalogList) n.id: n};
    final foods = await SupabaseService.getFoods(catalog);
    if (mounted) setState(() => _foods = foods);
    return foods;
  }

  Future<void> _editIngredient(_Ingredient ingredient) async {
    final amount =
        await _promptAmount(ingredient.food, initial: ingredient.amount);
    if (amount == null || !mounted) return;
    setState(() => ingredient.amount = amount);
  }

  /// Returns the weight of one ingredient, or null if it was cancelled.
  Future<double?> _promptAmount(Food food, {double? initial}) {
    return showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(
        title: food.label,
        unit: food.baseUnit,
        initial: initial,
      ),
    );
  }

  // --- Sections ---

  void _addSection() {
    setState(() => _sections.add(_SectionDraft.empty()));
  }

  void _removeSection(int index) {
    setState(() => _sections.removeAt(index).dispose());
  }

  void _moveSection(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _sections.length) return;
    setState(() {
      final section = _sections.removeAt(index);
      _sections.insert(target, section);
    });
  }

  void _addLine(_SectionDraft section) {
    setState(() => section.items.add(TextEditingController()));
  }

  void _removeLine(_SectionDraft section, int index) {
    setState(() => section.items.removeAt(index).dispose());
  }

  // --- Saving ---

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dê um nome à receita.')));
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

    // A section with no title and no lines is a leftover from tapping
    // "Adicionar seção" - dropping it beats refusing to save.
    final sections = [
      for (final section in _sections)
        if (!section.isEmpty) section.toSection(),
    ];
    final ingredients = [
      for (final ingredient in _ingredients)
        {'food_id': ingredient.food.id, 'amount': ingredient.amount},
    ];

    setState(() => _isSaving = true);
    try {
      final image = _imageController.text.trim();
      final prep = _prepController.text.trim();
      final total = _totalController.text.trim();
      if (_isNew) {
        await SupabaseService.createRecipe(
          name: name,
          image: image.isEmpty ? null : image,
          prepTime: prep.isEmpty ? null : prep,
          totalTime: total.isEmpty ? null : total,
          yieldAmount: yieldAmount,
          sections: sections,
          ingredients: ingredients,
        );
      } else {
        await SupabaseService.updateRecipe(
          widget.recipe!.id,
          name: name,
          image: image.isEmpty ? null : image,
          prepTime: prep.isEmpty ? null : prep,
          totalTime: total.isEmpty ? null : total,
          yieldAmount: yieldAmount,
          sections: sections,
          ingredients: ingredients,
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
      await SupabaseService.deleteRecipe(recipe.id);
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
            for (var i = 0; i < _sections.length; i++) ...[
              _buildSectionCard(i),
              const SizedBox(height: 20),
            ],
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _addSection,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar seção'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                side: BorderSide(color: AppTheme.borderOrange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
            ),
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

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _buildCard(children: [
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.sentences,
        decoration: _fieldDecoration(label: 'Nome da receita'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _imageController,
        keyboardType: TextInputType.url,
        decoration: _fieldDecoration(label: 'Link da foto (opcional)'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _prepController,
              decoration: _fieldDecoration(label: 'Preparo'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _totalController,
              decoration: _fieldDecoration(label: 'Tempo total'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Os tempos são texto livre: "30 min", "24 horas".',
        style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
      ),
    ]);
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

  /// The fixed section. Unlike the others it is not free text: every line
  /// is a catalogued food with a weight, which is the whole reason the
  /// nutrition screen can score a plate of this.
  Widget _buildIngredientsCard() {
    final preview = _preview;
    final weight = _weight;
    final totalKcal = preview.nutrients[NutrientId.calories]?.amount ?? 0;
    final per100 = weight > 0 ? totalKcal * 100 / weight : 0.0;

    return _buildCard(children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
            ),
            child: const Icon(Icons.shopping_basket,
                size: 18, color: AppTheme.primaryOrange),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Ingredientes', style: AppTheme.sectionTitle),
          ),
          Text(
            _ingredients.isEmpty
                ? ''
                : '${formatQuantity(_ingredientsAmount)} g',
            style: AppTheme.caption,
          ),
        ],
      ),
      const SizedBox(height: 4),
      if (_ingredients.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Os ingredientes vêm do catálogo de alimentos, com o peso de '
            'cada um. É isso que deixa a receita ser registrada em '
            '"Nutrição" - sem eles, ela é só o modo de preparo.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ),
      for (final ingredient in _ingredients) _buildIngredientRow(ingredient),
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
      if (_ingredients.isNotEmpty) ...[
        const Divider(height: 28, color: AppTheme.lightPeach),
        TextField(
          controller: _yieldController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration:
              _fieldDecoration(label: 'Rendimento (opcional)', suffix: 'g'),
        ),
        const SizedBox(height: 8),
        Text(
          'Quanto pesa o prato pronto. Em branco, vale a soma dos '
          'ingredientes - preencha quando parte da água evapora no '
          'cozimento, para que 100 g do prato contem certo.',
          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStat('Peso final',
                weight > 0 ? '${formatQuantity(weight)} g' : '—'),
            const SizedBox(width: 24),
            _buildStat('Receita inteira',
                weight > 0 ? '${totalKcal.round()} kcal' : '—'),
            const SizedBox(width: 24),
            _buildStat(
                'Por 100 g', weight > 0 ? '${per100.round()} kcal' : '—'),
          ],
        ),
        if (_weight < _ingredientsAmount) ...[
          const SizedBox(height: 10),
          Text(
            'O prato pronto pesa menos que os ingredientes: os '
            'nutrientes continuam os mesmos, só ficam mais '
            'concentrados por grama.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ],
    ]);
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
                      '${formatQuantity(ingredient.amount)} '
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

  /// A free-form section: a title of the cook's choosing and a list of
  /// lines. "Modo de preparo", "Antes de gelar", "Dicas" - the app has
  /// no opinion about any of it.
  Widget _buildSectionCard(int index) {
    final section = _sections[index];

    return _buildCard(children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: section.title,
              textCapitalization: TextCapitalization.sentences,
              style: AppTheme.sectionTitle,
              decoration: _fieldDecoration(label: 'Título da seção'),
            ),
          ),
          IconButton(
            onPressed: _isSaving || index == 0
                ? null
                : () => _moveSection(index, -1),
            icon: const Icon(Icons.arrow_upward, size: 18),
            color: AppTheme.mediumBrown,
            visualDensity: VisualDensity.compact,
            tooltip: 'Subir',
          ),
          IconButton(
            onPressed: _isSaving || index == _sections.length - 1
                ? null
                : () => _moveSection(index, 1),
            icon: const Icon(Icons.arrow_downward, size: 18),
            color: AppTheme.mediumBrown,
            visualDensity: VisualDensity.compact,
            tooltip: 'Descer',
          ),
          IconButton(
            onPressed: _isSaving ? null : () => _removeSection(index),
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppTheme.mediumBrown,
            visualDensity: VisualDensity.compact,
            tooltip: 'Excluir seção',
          ),
        ],
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < section.items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 12, right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      )),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: section.items[i],
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  decoration: _fieldDecoration(label: 'Passo ${i + 1}'),
                ),
              ),
              IconButton(
                onPressed:
                    _isSaving ? null : () => _removeLine(section, i),
                icon: Icon(Icons.close,
                    size: 18,
                    color: AppTheme.mediumBrown.withValues(alpha: 0.6)),
                tooltip: 'Remover linha',
              ),
            ],
          ),
        ),
      TextButton.icon(
        onPressed: _isSaving ? null : () => _addLine(section),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Adicionar linha'),
        style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryOrange),
      ),
    ]);
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
