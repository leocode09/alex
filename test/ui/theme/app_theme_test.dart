import 'package:alex/ui/design_system/app_tokens.dart';
import 'package:alex/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app theme uses flat style invariants', () {
    final theme = AppTheme.lightTheme;

    expect(theme.fontFamily, 'SpaceGrotesk');
    expect(theme.shadowColor, Colors.transparent);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.floatingActionButtonTheme.elevation, 0);
    expect(theme.navigationBarTheme.elevation, 0);
    expect(theme.dialogTheme.elevation, 0);
    expect(theme.bottomSheetTheme.elevation, 0);
    expect(theme.colorScheme.primary, AppTokens.accent);
    expect(theme.colorScheme.surfaceTint, Colors.transparent);
    expect(theme.extensions.values.isNotEmpty, isTrue);
  });
}
