import 'package:flutter/material.dart';
import 'app_tokens.dart';

@immutable
class AppThemeExtras extends ThemeExtension<AppThemeExtras> {
  final Color panel;
  final Color panelAlt;
  final Color border;
  final Color borderStrong;
  final Color muted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color accentSoft;

  // Glassmorphism semantics.
  final Color glassFill;
  final Color glassFillStrong;
  final Color glassBorder;
  final Color glassHighlight;
  final Color noiseColor;
  final double noiseOpacity;

  // Backdrop gradient blob colors.
  final Color backdropBase;
  final Color backdropWarm;
  final Color backdropAmber;
  final Color backdropCool;

  const AppThemeExtras({
    required this.panel,
    required this.panelAlt,
    required this.border,
    required this.borderStrong,
    required this.muted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.accentSoft,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassBorder,
    required this.glassHighlight,
    required this.noiseColor,
    required this.noiseOpacity,
    required this.backdropBase,
    required this.backdropWarm,
    required this.backdropAmber,
    required this.backdropCool,
  });

  static const AppThemeExtras light = AppThemeExtras(
    panel: AppTokens.paper,
    panelAlt: AppTokens.paperAlt,
    border: AppTokens.line,
    borderStrong: AppTokens.lineStrong,
    muted: AppTokens.mutedText,
    success: AppTokens.success,
    warning: AppTokens.warning,
    danger: AppTokens.danger,
    accentSoft: AppTokens.accentSoft,
    glassFill: Color(0xC2FFFFFF),
    glassFillStrong: Color(0xDEFFFFFF),
    glassBorder: Color(0x80FFFFFF),
    glassHighlight: Color(0x4DFFFFFF),
    noiseColor: Color(0xFF0D0D0D),
    noiseOpacity: AppTokens.noiseOpacityLight,
    backdropBase: AppTokens.backdropBaseLight,
    backdropWarm: AppTokens.backdropWarmLight,
    backdropAmber: AppTokens.backdropAmberLight,
    backdropCool: AppTokens.backdropCoolLight,
  );

  static const AppThemeExtras dark = AppThemeExtras(
    panel: Color(0xFF151515),
    panelAlt: Color(0xFF1D1D1D),
    border: Color(0xFF343434),
    borderStrong: Color(0xFF5C5C5C),
    muted: Color(0xFFB4B4B4),
    success: Color(0xFF57B86D),
    warning: Color(0xFFFFAE4C),
    danger: Color(0xFFFF7878),
    accentSoft: Color(0xFF4A2A10),
    glassFill: Color(0x6E2C2C30),
    glassFillStrong: Color(0xE0242428),
    glassBorder: Color(0x33FFFFFF),
    glassHighlight: Color(0x22FFFFFF),
    noiseColor: Color(0xFFFFFFFF),
    noiseOpacity: AppTokens.noiseOpacityDark,
    backdropBase: AppTokens.backdropBaseDark,
    backdropWarm: AppTokens.backdropWarmDark,
    backdropAmber: AppTokens.backdropAmberDark,
    backdropCool: AppTokens.backdropCoolDark,
  );

  @override
  AppThemeExtras copyWith({
    Color? panel,
    Color? panelAlt,
    Color? border,
    Color? borderStrong,
    Color? muted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? accentSoft,
    Color? glassFill,
    Color? glassFillStrong,
    Color? glassBorder,
    Color? glassHighlight,
    Color? noiseColor,
    double? noiseOpacity,
    Color? backdropBase,
    Color? backdropWarm,
    Color? backdropAmber,
    Color? backdropCool,
  }) {
    return AppThemeExtras(
      panel: panel ?? this.panel,
      panelAlt: panelAlt ?? this.panelAlt,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      muted: muted ?? this.muted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      accentSoft: accentSoft ?? this.accentSoft,
      glassFill: glassFill ?? this.glassFill,
      glassFillStrong: glassFillStrong ?? this.glassFillStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      noiseColor: noiseColor ?? this.noiseColor,
      noiseOpacity: noiseOpacity ?? this.noiseOpacity,
      backdropBase: backdropBase ?? this.backdropBase,
      backdropWarm: backdropWarm ?? this.backdropWarm,
      backdropAmber: backdropAmber ?? this.backdropAmber,
      backdropCool: backdropCool ?? this.backdropCool,
    );
  }

  @override
  ThemeExtension<AppThemeExtras> lerp(
    covariant ThemeExtension<AppThemeExtras>? other,
    double t,
  ) {
    if (other is! AppThemeExtras) {
      return this;
    }
    return AppThemeExtras(
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panelAlt: Color.lerp(panelAlt, other.panelAlt, t) ?? panelAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassFillStrong:
          Color.lerp(glassFillStrong, other.glassFillStrong, t) ??
              glassFillStrong,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassHighlight:
          Color.lerp(glassHighlight, other.glassHighlight, t) ?? glassHighlight,
      noiseColor: Color.lerp(noiseColor, other.noiseColor, t) ?? noiseColor,
      noiseOpacity: _lerpDouble(noiseOpacity, other.noiseOpacity, t),
      backdropBase: Color.lerp(backdropBase, other.backdropBase, t) ??
          backdropBase,
      backdropWarm: Color.lerp(backdropWarm, other.backdropWarm, t) ??
          backdropWarm,
      backdropAmber: Color.lerp(backdropAmber, other.backdropAmber, t) ??
          backdropAmber,
      backdropCool: Color.lerp(backdropCool, other.backdropCool, t) ??
          backdropCool,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension AppThemeExtrasX on BuildContext {
  AppThemeExtras get appExtras =>
      Theme.of(this).extension<AppThemeExtras>() ?? AppThemeExtras.light;
}
