import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadSavedThemeMode();
  }

  static const _themeModePrefsKey = 'theme_mode';

  Future<void> _loadSavedThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeModePrefsKey);
      state = _parseThemeMode(value);
    } catch (_) {
      // Keep default light mode when persistence is unavailable.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) {
      return;
    }
    state = mode;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModePrefsKey, mode.name);
    } catch (_) {
      // Keep runtime value even if persistence fails.
    }
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
}
