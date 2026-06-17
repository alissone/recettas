import 'package:flutter/material.dart';
import 'app_theme.dart';

class RecipeView extends StatefulWidget {
  final Map<String, dynamic> recipeData;

  const RecipeView({super.key, required this.recipeData});

  @override
  State<RecipeView> createState() => _RecipeViewState();
}

class _RecipeViewState extends State<RecipeView>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _iconRotations;
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    final sectionsCount = widget.recipeData['sections']?.length ?? 0;

    _controllers = List.generate(
      sectionsCount,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _iconRotations = _controllers
        .map((controller) => Tween<double>(begin: 0, end: 0.5).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut)))
        .toList();

    _isExpanded = List.filled(sectionsCount, false);
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleSection(int index) {
    setState(() {
      _isExpanded[index] = !_isExpanded[index];
      if (_isExpanded[index]) {
        _controllers[index].forward();
      } else {
        _controllers[index].reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPop)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
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
                ),

              // Header
              Text(
                widget.recipeData['name'] ?? 'Recipe',
                style: AppTheme.headingLarge,
              ),
              const SizedBox(height: 24),

              // Recipe Image
              if (widget.recipeData['image'] != null)
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
                      widget.recipeData['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryOrange.withValues(alpha:0.3),
                                AppTheme.lightOrange.withValues(alpha:0.3),
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

              // Recipe Info Cards
              if (widget.recipeData['prep_time'] != null ||
                  widget.recipeData['total_time'] != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      if (widget.recipeData['prep_time'] != null)
                        Expanded(
                          child: _buildInfoCard(
                            'Prep Time',
                            widget.recipeData['prep_time'],
                            Icons.schedule,
                          ),
                        ),
                      if (widget.recipeData['prep_time'] != null &&
                          widget.recipeData['total_time'] != null)
                        const SizedBox(width: 12),
                      if (widget.recipeData['total_time'] != null)
                        Expanded(
                          child: _buildInfoCard(
                            'Total Time',
                            widget.recipeData['total_time'],
                            Icons.timer,
                          ),
                        ),
                    ],
                  ),
                ),

              // Recipe Sections
              if (widget.recipeData['sections'] != null)
                ...List.generate(
                  widget.recipeData['sections'].length,
                  (index) => _buildExpandableSection(
                    widget.recipeData['sections'][index],
                    index,
                  ),
                ),
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
              color: AppTheme.primaryOrange.withValues(alpha:0.1),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusXSmall),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryOrange,
              size: 20,
            ),
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

  Widget _buildExpandableSection(
      Map<String, dynamic> section, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleSection(index),
            borderRadius:
                BorderRadius.circular(AppTheme.radiusLarge),
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
                    child: Icon(
                      _getSectionIcon(section['title']),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      section['title'] ?? 'Section',
                      style: AppTheme.sectionTitle,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _iconRotations[index],
                    builder: (context, child) {
                      return Transform.rotate(
                        angle:
                            _iconRotations[index].value * 3.14159,
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppTheme.primaryOrange,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(
                    color: AppTheme.lightPeach,
                    thickness: 1,
                  ),
                  const SizedBox(height: 16),
                  if (section['items'] != null)
                    ...List.generate(
                      section['items'].length,
                      (itemIndex) => _buildSectionItem(
                        section['items'][itemIndex],
                        itemIndex,
                      ),
                    ),
                ],
              ),
            ),
            crossFadeState: _isExpanded[index]
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionItem(dynamic item, int index) {
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
              color: AppTheme.primaryOrange.withValues(alpha:0.15),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusTiny),
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
          Expanded(
            child: Text(
              item.toString(),
              style: AppTheme.bodyText,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSectionIcon(String? title) {
    if (title == null) return Icons.list_alt;

    final titleLower = title.toLowerCase();
    if (titleLower.contains('ingredient')) return Icons.shopping_basket;
    if (titleLower.contains('mix')) return Icons.blender;
    if (titleLower.contains('fridge') || titleLower.contains('cold')) {
      return Icons.ac_unit;
    }
    if (titleLower.contains('bake') || titleLower.contains('oven')) {
      return Icons.local_fire_department;
    }
    if (titleLower.contains('preparation') ||
        titleLower.contains('prep')) {
      return Icons.timer;
    }

    return Icons.list_alt;
  }
}
