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
    );
  }
}

extension AppThemeExtrasX on BuildContext {
  AppThemeExtras get appExtras =>
      Theme.of(this).extension<AppThemeExtras>() ?? AppThemeExtras.light;
}
