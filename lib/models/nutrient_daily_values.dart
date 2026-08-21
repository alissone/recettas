import 'nutrient.dart';

/// FDA "Daily Value" reference amounts printed on US Nutrition Facts
/// labels (21 CFR 101.9(c)(8)-(9), current since the 2016 label rule), for
/// adults and children 4+ years on a 2,000 kcal reference diet.
///
/// Used as a fallback target for any nutrient the active recommendation
/// set doesn't cover - the shared "Adulto - VD ANVISA" preset
/// (migrations/016_create_nutrient_recommendations.sql) only sets seven
/// nutrients, so without this most vitamins and trace minerals would show
/// no Meta/% Meta on the trend card and never qualify for a nutrient
/// alert, no matter how low intake was.
///
/// Values are in the same unit public.nutrients uses for that id (mg or
/// ug, matching the label's own units - see migrations/014 and 020), so
/// they drop straight into intake/target math with no conversion.
///
/// A few of these (fat, saturatedFat, cholesterol, sodium, addedSugar)
/// are ceilings ("less than X") rather than minimums - see
/// `_ceilingNutrients` in nutrition_screen.dart, which is what actually
/// decides alert direction; this map only holds the numbers. Calories is
/// deliberately absent: NutritionScreen already derives its target from
/// the profile's RMR/TDEE estimate when one is available.
const Map<NutrientId, double> fdaDailyValues = {
  // Macronutrients
  NutrientId.fat: 78, // g
  NutrientId.saturatedFat: 20, // g
  NutrientId.cholesterol: 300, // mg
  NutrientId.sodium: 2300, // mg
  NutrientId.carbohydrates: 275, // g
  NutrientId.fiber: 28, // g
  // 10% of a 2000 kcal diet at 4 kcal/g. NutritionScreen recomputes this
  // from the user's actual calorie target instead of using this flat
  // number, falling back to it only when no calorie target is set.
  NutrientId.addedSugar: 50, // g
  NutrientId.protein: 50, // g
  NutrientId.potassium: 4700, // mg

  // Vitamins
  NutrientId.vitaminA: 900, // ug RAE
  NutrientId.vitaminC: 90, // mg
  NutrientId.vitaminD: 20, // ug
  NutrientId.vitaminE: 15, // mg
  NutrientId.vitaminK: 120, // ug
  NutrientId.vitaminB1: 1.2, // mg
  NutrientId.vitaminB2: 1.3, // mg
  NutrientId.vitaminB3: 16, // mg
  NutrientId.vitaminB6: 1.7, // mg
  NutrientId.vitaminB9: 400, // ug DFE (folate)
  NutrientId.vitaminB12: 2.4, // ug
  NutrientId.vitaminB7: 30, // ug (biotin)
  NutrientId.vitaminB5: 5, // mg (pantothenic acid)
  NutrientId.choline: 550, // mg

  // Minerals
  NutrientId.calcium: 1300, // mg
  NutrientId.iron: 18, // mg
  NutrientId.phosphorus: 1250, // mg
  NutrientId.iodine: 150, // ug
  NutrientId.magnesium: 420, // mg
  NutrientId.zinc: 11, // mg
  NutrientId.selenium: 55, // ug
  NutrientId.copper: 0.9, // mg
  NutrientId.manganese: 2.3, // mg
  NutrientId.chromium: 35, // ug
  NutrientId.molybdenum: 45, // ug
  NutrientId.chloride: 2300, // mg
};
