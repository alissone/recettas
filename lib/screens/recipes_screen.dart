import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/recipe.dart';
import '../services/supabase_service.dart';
import '../recipe_view.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Recipe> _recipes = [];
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
      final recipes = await SupabaseService.getRecipes();
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Recipes', style: AppTheme.headingLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Discover delicious meals',
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                size: 64, color: AppTheme.primaryOrange.withValues(alpha:0.4)),
            const SizedBox(height: 16),
            const Text('Could not load recipes',
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
              label: const Text('Retry'),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu,
              size: 64, color: AppTheme.primaryOrange.withValues(alpha:0.3)),
          const SizedBox(height: 16),
          const Text('No recipes yet', style: AppTheme.sectionTitle),
          const SizedBox(height: 8),
          const Text('Check back later!', style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeView(
              recipeData: {
                'name': recipe.name,
                'image': recipe.image,
                'prep_time': recipe.prepTime,
                'total_time': recipe.totalTime,
                'sections':
                    recipe.sections.map((s) => s.toMap()).toList(),
              },
            ),
          ),
        );
      },
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
                  Text(
                    recipe.name,
                    style: AppTheme.sectionTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (recipe.sections.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${recipe.sections.length} sections',
                      style: AppTheme.caption,
                    ),
                  ],
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

  Widget _buildCardImage(Recipe recipe) {
    if (recipe.image != null) {
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
            AppTheme.primaryOrange.withValues(alpha:0.15),
            AppTheme.lightOrange.withValues(alpha:0.15),
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
        color: AppTheme.primaryOrange.withValues(alpha:0.1),
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
