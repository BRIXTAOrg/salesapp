import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppDesign {
  // ----------------------------------------------------------
  // SPACING
  // ----------------------------------------------------------

  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  // ----------------------------------------------------------
  // EDITORIAL PALETTE
  // ----------------------------------------------------------

  static const ink = Color(0xFF1C1C1C);

  static const muted = Color(0xFF696862);

  static const faint = Color(0xFFA7A59E);

  static const canvas = Color(0xFFF7F6F2);

  static const surface = Color(0xFFFBFAF6);

  static const white = Color(0xFFFFFFFF);

  static const line = Color(0xFFE5E4DE);

  static const softGray = Color(0xFFF0EFEA);

  static const primary = Color(0xFF3D7068);

  static const blue = Color(0xFF3B82F6);

  static const green = primary;

  static const greenDark = Color(0xFF315C56);

  static const greenBright = Color(0xFF4B8179);

  static const amber = Color(0xFF8A6A2F);

  static const red = Color(0xFF9B3F3F);

  static const softBlue = Color(0xFFEDF1F4);

  static const softGreen = Color(0xFFEAF0EE);

  static const greenWash = Color(0xFFF0F3F1);

  static const softAmber = Color(0xFFF3EFE5);

  static const softRed = Color(0xFFF3E9E7);

  static const softViolet = softBlue;

  // Compatibility aliases.
  static const lavender = softBlue;

  static const sky = softBlue;

  static const lemon = softAmber;

  static const mint = softGreen;

  static const peach = softRed;

  static const tadaBlue = softBlue;

  static const tadaMint = softGreen;

  static const tadaViolet = softBlue;

  static const tadaGold = softAmber;

  // ----------------------------------------------------------
  // STRUCTURE
  // ----------------------------------------------------------

  static const pagePadding = EdgeInsets.symmetric(horizontal: s24);

  static const pageInset = EdgeInsets.fromLTRB(s24, s24, s24, s48);

  // ----------------------------------------------------------
  // BRIXTA PICTURE-FIRST GEOMETRY V2
  //
  // Consumer-quality presentation without changing the operational
  // information architecture.
  // ----------------------------------------------------------

  static const radius = 24.0;
  static const controlRadius = 18.0;
  static const heroRadius = 32.0;
  static const sheetRadius = 30.0;
  static const pillRadius = 999.0;

  // ----------------------------------------------------------
  // EDITORIAL MOTION
  // cubic-bezier(0.16, 1, 0.3, 1)
  // ----------------------------------------------------------

  static const editorialDuration = Duration(milliseconds: 850);

  static const editorialCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // ----------------------------------------------------------
  // TYPOGRAPHY
  // ----------------------------------------------------------

  static TextStyle serif({
    double size = 32,
    Color color = ink,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  static TextStyle sans({
    double size = 14,
    Color color = ink,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double size = 10,
    Color color = muted,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 2.0,
    double? height,
  }) {
    return GoogleFonts.spaceMono(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ----------------------------------------------------------
  // MATERIAL THEME
  // ----------------------------------------------------------

  static ThemeData theme() {
    final textTheme = GoogleFonts.spaceGroteskTextTheme()
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          displayLarge: serif(size: 56, height: .96, letterSpacing: -1.8),
          displayMedium: serif(size: 46, height: 1.0, letterSpacing: -1.4),
          displaySmall: serif(size: 40, height: 1.02, letterSpacing: -1.1),
          headlineLarge: serif(size: 38, height: 1.02, letterSpacing: -1.0),
          headlineMedium: serif(size: 30, height: 1.05, letterSpacing: -.7),
          headlineSmall: serif(size: 25, height: 1.08, letterSpacing: -.45),
          titleLarge: serif(size: 22, height: 1.12, letterSpacing: -.3),
          titleMedium: sans(size: 15, weight: FontWeight.w600, height: 1.3),
          titleSmall: mono(
            size: 10,
            color: ink,
            weight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
          bodyLarge: sans(size: 16, height: 1.5),
          bodyMedium: sans(size: 14, color: muted, height: 1.5),
          bodySmall: sans(size: 12, color: muted, height: 1.45),
          labelLarge: mono(
            size: 10,
            color: ink,
            weight: FontWeight.w600,
            letterSpacing: 2.2,
          ),
          labelMedium: mono(
            size: 9,
            color: muted,
            weight: FontWeight.w500,
            letterSpacing: 1.8,
          ),
          labelSmall: mono(size: 8, color: faint, letterSpacing: 1.6),
        );

    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: white,
      secondary: ink,
      onSecondary: white,
      surface: surface,
      onSurface: ink,
      error: red,
      onError: white,
      outline: line,
    );

    return ThemeData(
      useMaterial3: true,

      colorScheme: scheme,

      // Background comes from EditorialBackdrop.
      scaffoldBackgroundColor: Colors.transparent,

      canvasColor: Colors.transparent,

      cardColor: surface,

      splashFactory: InkRipple.splashFactory,

      visualDensity: VisualDensity.standard,

      textTheme: textTheme,

      iconTheme: const IconThemeData(color: ink, size: 20),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: Color(0x333D7068),
        selectionHandleColor: primary,
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: canvas.withValues(alpha: .88),
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleSpacing: s24,
        toolbarHeight: 64,
        shape: null,
        titleTextStyle: serif(size: 20, color: ink),
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

      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: mono(
            size: 10,
            color: white,
            weight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: line, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: mono(
            size: 10,
            color: ink,
            weight: FontWeight.w600,
            letterSpacing: 2.2,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: mono(
            size: 9,
            color: primary,
            weight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,

        labelStyle: mono(
          size: 9,
          color: muted,
          weight: FontWeight.w500,
          letterSpacing: 1.7,
        ),

        floatingLabelStyle: mono(
          size: 9,
          color: primary,
          weight: FontWeight.w600,
          letterSpacing: 1.7,
        ),

        hintStyle: mono(size: 10, color: faint, letterSpacing: .7),

        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 12),

        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: line, width: 1),
        ),

        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: line, width: 1),
        ),

        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primary, width: 1),
        ),

        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: red, width: 1),
        ),

        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: red, width: 1),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: canvas.withValues(alpha: .94),
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          mono(
            size: 8,
            color: ink,
            weight: FontWeight.w600,
            letterSpacing: 1.3,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillRadius),
        ),
        labelStyle: mono(size: 8, color: ink, letterSpacing: 1.2),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed,
        elevation: 0,
        backgroundColor: ink,
        contentTextStyle: sans(size: 13, color: white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(sheetRadius),
          ),
          side: const BorderSide(color: line),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: line,
      ),
    );
  }
}
