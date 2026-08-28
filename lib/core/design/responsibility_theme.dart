import 'package:flutter/material.dart';

const String brixtaPresentationContractId = 'brixta-presentation-v2';

const int brixtaPresentationRuntimeVersion = 2;

abstract final class ResponsibilityTheme {
  static String scope(Map<String, dynamic> document) {
    final raw = document['theme'];

    if (raw is! Map) {
      return 'inherit';
    }

    final value = raw['scope']?.toString();

    if (value == 'responsibility' || value == 'immersive') {
      return value!;
    }

    return 'inherit';
  }

  static bool immersive(Map<String, dynamic>? document) {
    if (document == null) {
      return false;
    }

    return scope(document) == 'immersive';
  }

  static ThemeData resolve(
    BuildContext context,
    Map<String, dynamic> document,
  ) {
    /*
     * THIS IS IMPORTANT:
     *
     * We start with the exact ThemeData already manufactured by BrixtaApp:
     *
     *   TenantTheme.build(...)
     *       -> AppDesign.theme()
     *
     * A Responsibility never starts from a random standalone ThemeData.
     */
    final base = Theme.of(context);

    final themeRaw = document['theme'];

    if (themeRaw is! Map || scope(document) == 'inherit') {
      return base;
    }

    final theme = Map<String, dynamic>.from(themeRaw);

    final tokensRaw = theme['tokens'];

    final tokens = tokensRaw is Map
        ? Map<String, dynamic>.from(tokensRaw)
        : <String, dynamic>{};

    final colorsRaw = tokens['colors'];

    final colors = colorsRaw is Map
        ? Map<String, dynamic>.from(colorsRaw)
        : <String, dynamic>{};

    final typographyRaw = tokens['typography'];

    final typography = typographyRaw is Map
        ? Map<String, dynamic>.from(typographyRaw)
        : <String, dynamic>{};

    final baseScheme = base.colorScheme;

    final primary = _color(colors['primary']) ?? baseScheme.primary;

    final background =
        _color(colors['background']) ?? base.scaffoldBackgroundColor;

    final surface = _color(colors['surface']) ?? baseScheme.surface;

    final foreground = _color(colors['foreground']) ?? baseScheme.onSurface;

    final border = _color(colors['border']) ?? baseScheme.outline;

    final scale = (_number(typography['scale'], 1)).clamp(0.75, 1.6);

    final scheme = baseScheme.copyWith(
      primary: primary,

      surface: surface,

      onSurface: foreground,

      outline: border,
    );

    /*
     * We inherit the host font families/weights/spacing.
     * Only an explicit scale is applied here.
     *
     * MediaQuery/system accessibility text scaling continues to apply later.
     */
    final textTheme = base.textTheme.apply(fontSizeFactor: scale);

    return base.copyWith(
      colorScheme: scheme,

      textTheme: textTheme,

      scaffoldBackgroundColor: background,

      canvasColor: background,
    );
  }

  static Color background(BuildContext context, Map<String, dynamic> document) {
    final resolved = resolve(context, document);

    final value = resolved.scaffoldBackgroundColor;

    if (value.a == 0) {
      return resolved.colorScheme.surface;
    }

    return value;
  }

  static Color? _color(dynamic value) {
    final raw = value?.toString().trim();

    if (raw == null || raw.isEmpty) {
      return null;
    }

    var hex = raw.replaceAll('#', '');

    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    if (hex.length != 8) {
      return null;
    }

    final number = int.tryParse(hex, radix: 16);

    return number == null ? null : Color(number);
  }

  static double _number(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
