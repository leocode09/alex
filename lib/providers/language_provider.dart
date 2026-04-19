import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app languages. Only [AppLanguage.englishUs] is fully translated
/// today; the remaining entries are persisted for the user's future preference
/// but are flagged as `comingSoon` so the UI can show a friendly notice while
/// still continuing to render English copy.
enum AppLanguage {
  englishUs('en_US', 'English (US)', '\ud83c\uddfa\ud83c\uddf8', false),
  englishUk('en_GB', 'English (UK)', '\ud83c\uddec\ud83c\udde7', false),
  french('fr_FR', 'Français', '\ud83c\uddeb\ud83c\uddf7', true),
  spanish('es_ES', 'Español', '\ud83c\uddea\ud83c\uddf8', true),
  portuguese('pt_BR', 'Português (BR)', '\ud83c\udde7\ud83c\uddf7', true),
  swahili('sw_TZ', 'Kiswahili', '\ud83c\uddf9\ud83c\uddff', true);

  const AppLanguage(this.code, this.label, this.flag, this.comingSoon);

  final String code;
  final String label;
  final String flag;
  final bool comingSoon;

  static AppLanguage fromCode(String? code) {
    for (final lang in AppLanguage.values) {
      if (lang.code == code) {
        return lang;
      }
    }
    return AppLanguage.englishUs;
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.englishUs) {
    _load();
  }

  static const _prefsKey = 'app_language';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppLanguage.fromCode(prefs.getString(_prefsKey));
    } catch (_) {
      // Keep default if persistence fails.
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) {
      return;
    }
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language.code);
    } catch (_) {
      // Keep runtime value even if persistence fails.
    }
  }
}
