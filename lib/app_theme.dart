import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Colors
  static const Color primaryOrange = Color(0xFFFF8C42);
  static const Color lightOrange = Color(0xFFFFB366);
  static const Color darkBrown = Color(0xFF2D1B14);
  static const Color mediumBrown = Color(0xFF8B4513);
  static const Color lightBrown = Color(0xFF4A3429);
  static const Color creamBackground = Color(0xFFFFF8F3);
  static const Color lightPeach = Color(0xFFFFE4D6);
  static const Color white = Colors.white;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, lightOrange],
  );

  // Borders — every decorative border in the app uses one of these two.
  // (State borders — focus rings, error banners, selection highlights —
  // keep their own semantic colors.)
  static Color get borderOrange => primaryOrange.withValues(alpha: 0.25);
  static Color get borderBrown => mediumBrown.withValues(alpha: 0.3);

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primaryOrange.withValues(alpha: 0.08),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: primaryOrange.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get accentShadow => [
        BoxShadow(
          color: primaryOrange.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get imageShadow => [
        BoxShadow(
          color: primaryOrange.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // Border Radius
  static const double radiusLarge = 20.0;
  static const double radiusMedium = 16.0;
  static const double radiusSmall = 12.0;
  static const double radiusXSmall = 8.0;
  static const double radiusTiny = 6.0;

  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: darkBrown,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: darkBrown,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: darkBrown,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    color: lightBrown,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: mediumBrown,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle valueBold = TextStyle(
    fontSize: 16,
    color: darkBrown,
    fontWeight: FontWeight.bold,
  );

  // Theme Data
  static ThemeData get themeData => ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Inter',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: creamBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: creamBackground,
          elevation: 0,
          iconTheme: IconThemeData(color: darkBrown),
          titleTextStyle: TextStyle(
            color: darkBrown,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: white,
          selectedItemColor: primaryOrange,
          unselectedItemColor: mediumBrown.withValues(alpha: 0.5),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryOrange,
          foregroundColor: white,
        ),
      );

  // Common Decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(radiusLarge),
        boxShadow: cardShadow,
      );
}
