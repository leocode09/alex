import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Typography helpers. Numeric / monetary values use the monospace face with
/// tabular figures so digits align in columns and never jitter as they change.
class AppType {
  const AppType._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Monospace numeric style for balances, amounts, counts and other figures.
  static TextStyle numeric({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = -0.2,
    double? height,
  }) {
    return TextStyle(
      fontFamily: AppTokens.fontMono,
      fontFeatures: _tabular,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
    );
  }
}
