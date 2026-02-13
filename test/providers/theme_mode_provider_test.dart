import 'package:alex/providers/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to light mode when no preference is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('setThemeMode updates state and persists value', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(themeModeProvider.notifier)
        .setThemeMode(ThemeMode.system);

    final prefs = await SharedPreferences.getInstance();
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(prefs.getString('theme_mode'), 'system');
  });
}
