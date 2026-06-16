import 'package:flutter/material.dart';

class AppTokens {
  const AppTokens._();

  // Type families. Sans for UI text, mono for numeric / tabular data.
  static const String fontSans = 'SpaceGrotesk';
  static const String fontMono = 'IBMPlexMono';

  static const Color ink = Color(0xFF0D0D0D);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperAlt = Color(0xFFF3F3F3);
  static const Color line = Color(0xFFD2D2D2);
  static const Color lineStrong = Color(0xFF969696);
  static const Color mutedText = Color(0xFF4F4F4F);
  static const Color accent = Color(0xFFFF6A00);
  static const Color accentSoft = Color(0xFFFFE9D6);
  static const Color success = Color(0xFF1B8A3B);
  static const Color warning = Color(0xFFB76500);
  static const Color danger = Color(0xFFC62828);

  static const double radiusS = 8;
  static const double radiusM = 14;
  static const double radiusL = 20;
  static const double radiusXL = 26;

  static const double space1 = 6;
  static const double space2 = 10;
  static const double space3 = 14;
  static const double space4 = 20;
  static const double space5 = 28;

  static const double border = 1.0;
  static const double borderStrong = 1.5;

  // Glassmorphism: frosted-blur strengths (BackdropFilter sigma).
  static const double blurBar = 14;
  static const double blurPanel = 18;
  static const double blurStrong = 28;

  // Subtle film-grain opacity per brightness.
  static const double noiseOpacityLight = 0.03;
  static const double noiseOpacityDark = 0.04;

  // Backdrop gradient stops - light mode (neutral base + warm accent + cool blue).
  static const Color backdropBaseLight = Color(0xFFF4F5F8);
  static const Color backdropWarmLight = Color(0xFFFFD8BC);
  static const Color backdropAmberLight = Color(0xFFFFE9D6);
  static const Color backdropCoolLight = Color(0xFFCFE0FF);

  // Backdrop gradient stops - dark mode (deep charcoal + orange/indigo glow).
  static const Color backdropBaseDark = Color(0xFF0C0C0F);
  static const Color backdropWarmDark = Color(0xFF3A1E0A);
  static const Color backdropAmberDark = Color(0xFF241405);
  static const Color backdropCoolDark = Color(0xFF14203A);
}
