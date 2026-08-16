import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/food.dart';
import '../models/nutrient.dart';
import '../models/recipe.dart';
import '../services/supabase_service.dart';
import '../recipe_view.dart';
import 'recipe_editor_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Recipe> _recipes = [];

  /// The food catalog: it resolves the ingredients' nutrient values and
  /// is what the editor picks new ingredients from.
  List<Food> _foods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final catalogList = await SupabaseService.getNutrientCatalog();
      final catalog = {for (final n in catalogList) n.id: n};
      final foods = await SupabaseService.getFoods(catalog);
      final recipes = await SupabaseService.getRecipes(catalog);
      if (!mounted) return;
      setState(() {
        _foods = foods;
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Shared recipes (seeded in SQL, user_id null) are read-only - RLS
  /// would refuse the write anyway.
  bool _isOwn(Recipe recipe) =>
      recipe.userId != null &&
      recipe.userId == SupabaseService.currentUser?.id;

  Future<void> _createRecipe() async {
    if (SupabaseService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entre na sua conta para criar receitas.')));
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(foods: _foods),
      ),
    );
    if (saved == true) await _loadRecipes();
  }

  /// Opens the editor for [recipe] and reports back what it became, so
  /// the open detail view can refresh itself.
  Future<Recipe?> _editRecipe(Recipe recipe) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(foods: _foods, recipe: recipe),
      ),
    );
    if (saved != true || !mounted) return null;
    await _loadRecipes();
    if (!mounted) return null;

    final updated =
        _recipes.where((r) => r.id == recipe.id).firstOrNull;
    if (updated == null) {
      // It was deleted: close the detail view, which is the top route
      // now that the editor has popped.
      Navigator.of(context).pop();
    }
    return updated;
  }

  void _openRecipe(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeView(
          recipe: recipe,
          onEdit: _isOwn(recipe) ? _editRecipe : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _createRecipe,
              tooltip: 'Nova receita',
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Receitas', style: AppTheme.headingLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'O que fazer, e o que isso rende',
                style:
                    AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_recipes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadRecipes,
      color: AppTheme.primaryOrange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        itemCount: _recipes.length,
        itemBuilder: (context, index) => _buildRecipeCard(_recipes[index]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 64,
                color: AppTheme.primaryOrange.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Não deu para carregar as receitas',
                style: AppTheme.sectionTitle),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTheme.caption,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRecipes,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar de novo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: AppTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSmall),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu,
                size: 64,
                color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Nenhuma receita ainda',
                style: AppTheme.sectionTitle),
            const SizedBox(height: 8),
            Text(
              'Toque em + para escrever a primeira. Com a lista de '
              'ingredientes preenchida, ela também pode ser registrada '
              'em "Nutrição".',
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final weight = recipe.weight;
    final per100 = recipe.isLoggable
        ? (recipe.nutrients[NutrientId.calories]?.amount ?? 0) *
            100 /
            weight
        : null;

    return GestureDetector(
      onTap: () => _openRecipe(recipe),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: AppTheme.cardDecoration,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardImage(recipe),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: AppTheme.sectionTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isOwn(recipe)) _buildBadge('Modelo'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (recipe.ingredients.isNotEmpty)
                        '${recipe.ingredients.length} '
                            '${recipe.ingredients.length == 1 ? 'ingrediente' : 'ingredientes'}',
                      if (recipe.sections.isNotEmpty)
                        '${recipe.sections.length} '
                            '${recipe.sections.length == 1 ? 'seção' : 'seções'}',
                      if (per100 != null)
                        '${per100.round()} kcal por 100 g',
                    ].join(' · '),
                    style: AppTheme.caption,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (recipe.prepTime != null)
                        _buildTimeBadge(Icons.schedule, recipe.prepTime!),
                      if (recipe.prepTime != null &&
                          recipe.totalTime != null)
                        const SizedBox(width: 10),
                      if (recipe.totalTime != null)
                        _buildTimeBadge(Icons.timer, recipe.totalTime!),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusXSmall),
                          boxShadow: AppTheme.accentShadow,
                        ),
                        child: const Icon(Icons.arrow_forward,
                            size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildCardImage(Recipe recipe) {
    if (recipe.image != null && recipe.image!.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 180,
        child: Image.network(
          recipe.image!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        ),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withValues(alpha: 0.15),
            AppTheme.lightOrange.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_menu,
            size: 48, color: AppTheme.mediumBrown),
      ),
    );
  }

  Widget _buildTimeBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryOrange),
          const SizedBox(width: 4),
          Text(text,
              style: AppTheme.caption
                  .copyWith(color: AppTheme.primaryOrange)),
        ],
      ),
    );
  }
}
