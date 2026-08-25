import 'package:flutter/material.dart';

abstract final class AppDesign {
  // Existing restrained 8pt system retained.
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF4B5563);
  static const faint = Color(0xFF9CA3AF);
  static const canvas = Color(0xFFF8FAF9);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E9E5);
  static const softGray = Color(0xFFF2F5F3);

  // BRIXTA live/runtime accent. The visual language stays neutral; green is
  // reserved for primary action, online/live state and successful progress.
  static const primary = Color(0xFF15803D);
  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF15803D);
  static const greenDark = Color(0xFF166534);
  static const greenBright = Color(0xFF16A34A);
  static const amber = Color(0xFFB45309);
  static const red = Color(0xFFB91C1C);

  static const softBlue = Color(0xFFEFF6FF);
  static const softGreen = Color(0xFFF0FDF4);
  static const greenWash = Color(0xFFF5FBF7);
  static const softAmber = Color(0xFFFFFBEB);
  static const softRed = Color(0xFFFEF2F2);
  static const softViolet = softBlue;

  // Backward-compatible aliases.
  static const lavender = softBlue;
  static const sky = softBlue;
  static const lemon = softAmber;
  static const mint = softGreen;
  static const peach = softRed;
  static const tadaBlue = softBlue;
  static const tadaMint = softGreen;
  static const tadaViolet = softBlue;
  static const tadaGold = softAmber;

  static const pagePadding = EdgeInsets.symmetric(horizontal: s24);
  static const pageInset = EdgeInsets.fromLTRB(s24, s24, s24, s48);

  static const radius = 10.0;
  static const controlRadius = 8.0;

  static ThemeData theme() {
    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: ink,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: ink,
      error: red,
      onError: Colors.white,
      outline: line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          height: 1.12,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.48,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.32,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.24,
          color: muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleSpacing: s24,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.32,
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
          side: const BorderSide(color: line, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: Color(0xFFD1D8D3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        hintStyle: const TextStyle(color: faint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: Color(0xFFD1D8D3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: Color(0xFFD1D8D3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: red),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: softGreen,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: softGray,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ink),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    );
  }
}
