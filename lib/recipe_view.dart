import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models/nutrient.dart';
import 'models/recipe.dart';

/// Reads one recipe: the picture and times up top, then the ingredient
/// list, then whatever sections the cook wrote, each collapsible.
///
/// Ingredients come first and always look the same because they are the
/// one structured part - catalogued foods with weights, which is also
/// what the nutrition screen scores a portion by. Everything after them
/// is free text.
class RecipeView extends StatefulWidget {
  final Recipe recipe;

  /// Opens the editor and returns the recipe as it stands afterwards, or
  /// null when nothing changed. A null callback means read-only, which
  /// is the case for the shared recipes nobody owns.
  final Future<Recipe?> Function(Recipe recipe)? onEdit;

  const RecipeView({super.key, required this.recipe, this.onEdit});

  @override
  State<RecipeView> createState() => _RecipeViewState();
}

class _RecipeViewState extends State<RecipeView> {
  late Recipe _recipe = widget.recipe;

  /// Which panels are open, by their index in [_panels].
  final Set<int> _expanded = {};

  Future<void> _edit() async {
    final updated = await widget.onEdit!(_recipe);
    if (updated == null || !mounted) return;
    setState(() {
      _recipe = updated;
      _expanded.clear();
    });
  }

  void _toggle(int index) {
    setState(() {
      if (!_expanded.remove(index)) _expanded.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final sections = _recipe.sections;
    final hasIngredients = _recipe.ingredients.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (canPop)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: AppTheme.darkBrown, size: 24),
                      ),
                    ),
                  const Spacer(),
                  if (widget.onEdit != null)
                    GestureDetector(
                      onTap: _edit,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: AppTheme.darkBrown, size: 24),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Header
              Text(_recipe.name, style: AppTheme.headingLarge),
              const SizedBox(height: 24),

              // Recipe image
              if (_recipe.image != null && _recipe.image!.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 220,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: AppTheme.imageShadow,
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    child: Image.network(
                      _recipe.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryOrange
                                    .withValues(alpha: 0.3),
                                AppTheme.lightOrange.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 60,
                              color: AppTheme.mediumBrown,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Times
              if (_recipe.prepTime != null || _recipe.totalTime != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      if (_recipe.prepTime != null)
                        Expanded(
                          child: _buildInfoCard(
                            'Preparo',
                            _recipe.prepTime!,
                            Icons.schedule,
                          ),
                        ),
                      if (_recipe.prepTime != null &&
                          _recipe.totalTime != null)
                        const SizedBox(width: 12),
                      if (_recipe.totalTime != null)
                        Expanded(
                          child: _buildInfoCard(
                            'Tempo total',
                            _recipe.totalTime!,
                            Icons.timer,
                          ),
                        ),
                    ],
                  ),
                ),

              // What the finished dish is worth, once it has an
              // ingredient list to add up.
              if (_recipe.isLoggable) _buildNutritionCard(),

              // Ingredients first, then the free-form sections.
              if (hasIngredients) _buildIngredientsPanel(0),
              for (var i = 0; i < sections.length; i++)
                _buildSectionPanel(
                    sections[i], hasIngredients ? i + 1 : i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.caption),
                Text(value, style: AppTheme.valueBold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard() {
    final weight = _recipe.weight;
    final totalKcal =
        _recipe.nutrients[NutrientId.calories]?.amount ?? 0;
    final per100 = weight > 0 ? totalKcal * 100 / weight : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStat('Rende',
                  '${formatQuantity(weight)} g'),
              const SizedBox(width: 24),
              _buildStat('Receita inteira', '${totalKcal.round()} kcal'),
              const SizedBox(width: 24),
              _buildStat('Por 100 g', '${per100.round()} kcal'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Registre uma porção em "Nutrição" para somar isso ao dia.',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
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

  Widget _buildIngredientsPanel(int index) {
    return _buildPanel(
      index: index,
      icon: Icons.shopping_basket,
      title: 'Ingredientes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final ingredient in _recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 10, right: 14),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ingredient.label, style: AppTheme.bodyText),
                        Text(
                          '${ingredient.nutrient(NutrientId.calories).round()}'
                          ' kcal',
                          style: AppTheme.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionPanel(RecipeSection section, int index) {
    return _buildPanel(
      index: index,
      icon: _getSectionIcon(section.title),
      title: section.title.isEmpty ? 'Seção' : section.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < section.items.length; i++)
            _buildSectionItem(section.items[i], i),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required int index,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final isExpanded = _expanded.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggle(index),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                      boxShadow: AppTheme.accentShadow,
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title, style: AppTheme.sectionTitle),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.primaryOrange,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppTheme.lightPeach, thickness: 1),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionItem(String item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
          ),
          Expanded(child: Text(item, style: AppTheme.bodyText)),
        ],
      ),
    );
  }

  IconData _getSectionIcon(String title) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('ingredient')) return Icons.shopping_basket;
    if (titleLower.contains('mix') || titleLower.contains('mistur')) {
      return Icons.blender;
    }
    if (titleLower.contains('fridge') ||
        titleLower.contains('cold') ||
        titleLower.contains('gel')) {
      return Icons.ac_unit;
    }
    if (titleLower.contains('bake') ||
        titleLower.contains('oven') ||
        titleLower.contains('forno') ||
        titleLower.contains('assar')) {
      return Icons.local_fire_department;
    }
    if (titleLower.contains('preparation') ||
        titleLower.contains('prep')) {
      return Icons.timer;
    }

    return Icons.list_alt;
  }
}
