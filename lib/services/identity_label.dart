import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_state.dart';

/// The single human-readable identity used throughout the app.
///
/// A person's Firebase/member display name is authoritative. The cached
/// value keeps offline startup deterministic, while [fallback] deliberately
/// avoids exposing hardware model names or technical ids as a user label.
class IdentityLabel {
  IdentityLabel._();

  static const String fallback = 'Device';
  static const String preferenceKey = 'identity_display_name';

  // Kept as a compatibility mirror while older LAN code/installed builds
  // still read this preference during the rollout.
  static const String legacyLanPreferenceKey = 'lan_device_name';

  static final StreamController<String> _changes =
      StreamController<String>.broadcast();

  static String _current = fallback;
  static bool _initialized = false;

  static String get current => _current;
  static Stream<String> get changes => _changes.stream;

  /// Loads the last signed-in person's display name for offline startup.
  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final cached = _normalize(prefs.getString(preferenceKey));
    if (_current == fallback && cached != null) {
      _setCurrent(cached);
    }
    _initialized = true;
  }

  /// Applies a non-empty account display name without clearing the last
  /// known identity during transient loading or signed-out states.
  static Future<void> updateFromAccount(AccountState account) async {
    final name = _normalize(account.displayName);
    if (name == null) {
      return;
    }
    await update(name);
  }

  /// Persists a canonical display name and notifies active sync transports.
  static Future<void> update(String displayName) async {
    final name = _normalize(displayName);
    if (name == null) {
      return;
    }
    _setCurrent(name);
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(preferenceKey, name),
      prefs.setString(legacyLanPreferenceKey, name),
    ]);
    _initialized = true;
  }

  static void _setCurrent(String name) {
    if (_current == name) {
      return;
    }
    _current = name;
    if (!_changes.isClosed) {
      _changes.add(name);
    }
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
