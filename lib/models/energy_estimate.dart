/// Daily energy estimate built from the Profile screen's body-profile form:
/// RMR (Mifflin-St Jeor) -> non-exercise activity -> exercise -> thermic
/// effect of food -> TDEE -> goal calories. Every equation here is a
/// population-level approximation - individual metabolic rate varies
/// enough that this should read as a starting range, not a precise number.
class EnergyEstimate {
  /// Resting metabolic rate: calories burned at rest.
  final double rmr;

  /// Non-exercise activity - walking, standing, the job itself.
  final double neat;

  /// Daily average from weightlifting sessions.
  final double weightlifting;

  /// Daily average from cardio sessions.
  final double cardio;

  /// Thermic effect of food: energy spent digesting what's eaten.
  final double tef;

  /// Estimated maintenance calories: rmr + neat + weightlifting + cardio + tef.
  final double tdee;

  /// TDEE adjusted for the profile's stated goal and desired rate.
  final double goalCalories;

  /// A practical +/-10% band around [goalCalories], since no single number
  /// here is precise enough to hit exactly.
  final double rangeLow;
  final double rangeHigh;

  /// Calories on a day with no training, and on a day with one - both
  /// average out to [goalCalories] across the week's actual training
  /// split, rather than spreading exercise evenly over every day.
  final double restDayCalories;
  final double trainingDayCalories;
  final int trainingDaysPerWeek;

  /// [goalCalories] recomputed at each goal/rate combination, for a quick
  /// side-by-side ("what if I aimed to lose 0.5 kg/week instead?").
  final Map<String, double> goalOptions;

  const EnergyEstimate({
    required this.rmr,
    required this.neat,
    required this.weightlifting,
    required this.cardio,
    required this.tef,
    required this.tdee,
    required this.goalCalories,
    required this.rangeLow,
    required this.rangeHigh,
    required this.restDayCalories,
    required this.trainingDayCalories,
    required this.trainingDaysPerWeek,
    required this.goalOptions,
  });

  /// A kg/week rate, in kcal/day, at ~7700 kcal per kg of body fat - the
  /// same constant the Nutrition screen's weight projection uses.
  static double _dailyRate(double kgPerWeek) => kgPerWeek * 7700 / 7;

  static const _rates = {
    'slow': 0.25,
    'moderate': 0.5,
    'fast': 0.75,
  };

  static double _cardioMet(String? intensity, int? heartRate) {
    switch (intensity) {
      case 'easy':
        return 5.0;
      case 'hard':
        return 10.0;
      case 'moderate':
        return 7.0;
    }
    if (heartRate != null) {
      if (heartRate < 120) return 5.0;
      if (heartRate < 150) return 7.0;
      return 10.0;
    }
    // Days/minutes were filled in but not an intensity - assume moderate
    // rather than let a real session contribute nothing.
    return 7.0;
  }

  static double _liftMet(String? intensity) {
    switch (intensity) {
      case 'light':
        return 3.5;
      case 'hard':
        return 6.0;
    }
    return 5.0;
  }

  /// Null when the four fields Mifflin-St Jeor needs - sex, age, height,
  /// weight - aren't all filled in yet. Everything past RMR degrades
  /// gracefully: missing activity fields just contribute zero rather than
  /// blocking the estimate.
  static EnergyEstimate? fromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final sex = profile['sex'] as String?;
    final age = _int(profile['age']);
    final heightCm = _dbl(profile['height_cm']);
    final weightKg = _dbl(profile['weight_kg']);
    if (sex == null || age == null || heightCm == null || weightKg == null) {
      return null;
    }

    final rmr = sex == 'male'
        ? 10 * weightKg + 6.25 * heightCm - 5 * age + 5
        : 10 * weightKg + 6.25 * heightCm - 5 * age - 161;

    final steps = _int(profile['average_daily_steps']);
    final neat = steps != null && steps > 0
        ? steps * weightKg * 0.0005
        : rmr *
            switch (profile['occupation_activity']) {
              'standing' => 0.30,
              'physical' => 0.40,
              _ => 0.20, // unset or 'sedentary'
            };

    final liftDays = _int(profile['weightlifting_days_per_week']) ?? 0;
    final liftMinutes =
        _int(profile['weightlifting_minutes_per_session']) ?? 0;
    final liftMet = _liftMet(profile['lifting_intensity'] as String?);
    final weightliftingWeekly =
        liftDays * (liftMinutes / 60) * liftMet * weightKg;

    final cardioDays = _int(profile['cardio_days_per_week']) ?? 0;
    final cardioMinutes = _int(profile['cardio_minutes_per_session']) ?? 0;
    final cardioMet = _cardioMet(
        profile['cardio_intensity'] as String?, _int(profile['cardio_heart_rate']));
    final cardioWeekly = cardioDays * (cardioMinutes / 60) * cardioMet * weightKg;

    final weightlifting = weightliftingWeekly / 7;
    final cardio = cardioWeekly / 7;

    final beforeTef = rmr + neat + weightlifting + cardio;
    final tef = beforeTef * 0.10;
    final tdee = beforeTef + tef;

    final goal = profile['goal'] as String? ?? 'maintain';
    final goalRate = profile['goal_rate'] as String? ?? 'moderate';
    final rateKcal = _dailyRate(_rates[goalRate] ?? _rates['moderate']!);
    final goalCalories = switch (goal) {
      'lose' => tdee - rateKcal,
      'gain' => tdee + rateKcal,
      _ => tdee,
    };

    final goalOptions = <String, double>{'maintain': tdee};
    for (final entry in _rates.entries) {
      final delta = _dailyRate(entry.value);
      goalOptions['lose_${entry.key}'] = tdee - delta;
      goalOptions['gain_${entry.key}'] = tdee + delta;
    }

    final exerciseWeekly = weightliftingWeekly + cardioWeekly;
    final trainingDays =
        (liftDays + cardioDays) > 7 ? 7 : (liftDays + cardioDays);
    final nonExerciseGoal = goalCalories - exerciseWeekly / 7;
    final exercisePerTrainingDay =
        trainingDays > 0 ? exerciseWeekly / trainingDays : 0.0;

    return EnergyEstimate(
      rmr: rmr,
      neat: neat,
      weightlifting: weightlifting,
      cardio: cardio,
      tef: tef,
      tdee: tdee,
      goalCalories: goalCalories,
      rangeLow: goalCalories * 0.9,
      rangeHigh: goalCalories * 1.1,
      restDayCalories: nonExerciseGoal,
      trainingDayCalories: nonExerciseGoal + exercisePerTrainingDay,
      trainingDaysPerWeek: trainingDays,
      goalOptions: goalOptions,
    );
  }

  static double? _dbl(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  static int? _int(dynamic v) => v == null ? null : int.tryParse(v.toString());
}
