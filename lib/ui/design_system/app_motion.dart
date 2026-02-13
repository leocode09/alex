import 'package:flutter/material.dart';

class AppMotion {
  const AppMotion._();

  static const Duration sectionReveal = Duration(milliseconds: 220);
  static const Duration stateSwitch = Duration(milliseconds: 180);

  static const Curve sectionCurve = Curves.easeOutCubic;
  static const Curve stateCurve = Curves.easeOut;
}
