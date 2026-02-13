import 'package:alex/providers/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads saved theme mode from shared preferences', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('setThemeMode updates state and persists value', () async {
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
