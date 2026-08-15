import 'package:flutter/material.dart';

abstract final class AppDesign {
  static const ink = Color(0xFF1D1D1F);
  static const muted = Color(0xFF71717A);
  static const faint = Color(0xFFA1A1AA);
  static const canvas = Color(0xFFF8F8F7);
  static const surface = Colors.white;
  static const line = Color(0xFFE7E7E5);

  // Brand / actions.
  static const red = Color(0xFFE31C3D);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFF59E0B);
  static const blue = Color(0xFF2563EB);

  // Soft surfaces.
  static const softGray = Color(0xFFF2F2F1);
  static const softGreen = Color(0xFFECFDF5);
  static const softRed = Color(0xFFFFF1F2);
  static const softBlue = Color(0xFFEFF6FF);
  static const softAmber = Color(0xFFFFF8E7);
  static const softViolet = Color(0xFFF5F3FF);

  // Compatibility with the first playful pass.
  static const lavender = softViolet;
  static const sky = softBlue;
  static const lemon = softAmber;
  static const mint = softGreen;
  static const peach = softRed;

  // TA/DA delight palette.
  static const tadaBlue = softBlue;
  static const tadaMint = softGreen;
  static const tadaViolet = softViolet;
  static const tadaGold = softAmber;

  static const pagePadding = EdgeInsets.symmetric(horizontal: 18);
  static const radius = 20.0;

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: red,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(
      primary: ink,
      secondary: red,
      error: red,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          height: 1.03,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.08,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.45,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: faint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: ink, width: 1.4),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: softGray,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: softGray,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }
}
