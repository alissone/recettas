import 'food.dart';
import 'nutrient.dart';

/// A recipe: a name, a picture, an ingredient list, and however many
/// free-form sections the cook wants after it.
///
/// The ingredient list is the one fixed part. It is not text but rows
/// pointing at the food catalog with weights, which is what lets the
/// nutrition log score a plate of the finished dish. Everything else -
/// "Modo de preparo", "Antes de gelar", whatever - lives in [sections]
/// as a title and a list of lines.
class Recipe {
  final String id;

  /// Null for the shared recipes seeded in SQL, which nobody can edit.
  final String? userId;
  final String name;

  /// Image URL, not a storage path: recipes were seeded with links.
  final String? image;
  final String? prepTime;
  final String? totalTime;

  /// Weight of the finished dish when it differs from the sum of the
  /// ingredients - null means nothing was lost to cooking.
  final double? yieldAmount;

  /// Everything except the ingredients, in the order they are shown.
  final List<RecipeSection> sections;
  final List<RecipeIngredient> ingredients;
  final DateTime? createdAt;

  const Recipe({
    required this.id,
    this.userId,
    required this.name,
    this.image,
    this.prepTime,
    this.totalTime,
    this.yieldAmount,
    this.sections = const [],
    this.ingredients = const [],
    this.createdAt,
  });

  /// Everything that goes in, ml counted as g - the same non-conversion
  /// the rest of the nutrition schema makes.
  double get ingredientsAmount =>
      ingredients.fold<double>(0, (sum, i) => sum + i.amount);

  /// What a portion is measured against. Cooking losses only make the
  /// dish denser, never less nutritious, so they divide here and are
  /// absent from [nutrients].
  double get weight => yieldAmount != null && yieldAmount! > 0
      ? yieldAmount!
      : ingredientsAmount;

  /// Whether the finished dish weighs something other than what went
  /// into it.
  bool get hasYield => yieldAmount != null && yieldAmount! > 0;

  /// Whether this recipe can be logged as a meal. Recipes seeded before
  /// the ingredient list existed - or still being written - have nothing
  /// to compute from.
  bool get isLoggable => ingredients.isNotEmpty && weight > 0;

  /// Totals for the whole recipe, keyed by nutrient. An ingredient that
  /// says nothing about a nutrient simply doesn't contribute to it -
  /// which does mean a recipe is only as complete as its ingredients.
  Map<NutrientId, Nutrient> get nutrients {
    final totals = <NutrientId, Nutrient>{};
    for (final ingredient in ingredients) {
      if (ingredient.food.baseAmount <= 0) continue;
      for (final nutrient in ingredient.food.nutrients.values) {
        final contribution =
            nutrient.amount * ingredient.amount / ingredient.food.baseAmount;
        final running = totals[nutrient.id];
        totals[nutrient.id] = (running ?? nutrient).copyWith(
          amount: (running?.amount ?? 0) + contribution,
        );
      }
    }
    return totals;
  }

  /// The recipe seen as a single ingredient weighing [weight]. Every
  /// chart, total and target comparison in the nutrition screen then
  /// works on it unchanged.
  Food asFood() => Food(
        id: id,
        userId: userId,
        name: name,
        baseAmount: weight,
        baseUnit: 'g',
        nutrients: nutrients,
      );

  /// Expects `.select('*, ingredients:recipe_ingredients(*, food:foods(*,
  /// food_nutrients(nutrient_id, amount))))'`. [catalog] can be empty
  /// when only the ingredient names and weights are needed - the
  /// nutrient values are what it resolves.
  factory Recipe.fromJson(Map<String, dynamic> json,
      [Map<NutrientId, Nutrient> catalog = const {}]) {
    final rawSections = json['sections'];
    final sections = rawSections is List
        ? rawSections.map((s) => RecipeSection.fromJson(s)).toList()
        : <RecipeSection>[];

    final rawIngredients = json['ingredients'];
    final ingredients = rawIngredients is List
        ? rawIngredients
            .map((i) => RecipeIngredient.fromJson(i, catalog))
            .toList()
        : <RecipeIngredient>[];
    ingredients.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.food.name.compareTo(b.food.name);
    });

    final yieldAmount = json['yield_amount'];
    return Recipe(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'],
      name: json['name'] ?? '',
      image: json['image'],
      prepTime: json['prep_time'],
      totalTime: json['total_time'],
      yieldAmount: yieldAmount == null
          ? null
          : double.tryParse(yieldAmount.toString()),
      sections: sections,
      ingredients: ingredients,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

/// One line of the ingredient list: which catalogued food, and how much
/// of it the recipe calls for.
class RecipeIngredient {
  final String id;
  final Food food;

  /// In the ingredient's [Food.baseUnit].
  final double amount;
  final int sortOrder;

  const RecipeIngredient({
    required this.id,
    required this.food,
    required this.amount,
    this.sortOrder = 0,
  });

  /// How much of [id] this ingredient brings to the whole recipe.
  double nutrient(NutrientId id) =>
      food.baseAmount <= 0 ? 0 : food.get(id) * amount / food.baseAmount;

  /// "200 g de Farinha de trigo".
  String get label =>
      '${formatQuantity(amount)} ${food.baseUnit} de ${food.label}';

  /// Expects `.select('*, food:foods(*, food_nutrients(...))')`.
  factory RecipeIngredient.fromJson(
      Map<String, dynamic> json, Map<NutrientId, Nutrient> catalog) {
    return RecipeIngredient(
      id: json['id']?.toString() ?? '',
      food: Food.fromJson(json['food'] ?? const {}, catalog),
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

/// A titled list of lines - the free-form half of a recipe. Stored as
/// jsonb, so anything goes: preparation steps, resting times, notes.
class RecipeSection {
  final String title;
  final List<String> items;

  const RecipeSection({required this.title, required this.items});

  factory RecipeSection.fromJson(Map<String, dynamic> json) {
    return RecipeSection(
      title: json['title'] ?? '',
      items:
          (json['items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'items': items,
    };
  }
}
