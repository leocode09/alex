import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase for the app.
///
/// Offline-first contract: this MUST NEVER throw. If configuration is
/// missing (user has not yet run `flutterfire configure`) or init fails
/// for any other reason, [available] is set to false and the rest of the
/// app continues to work against local storage only.
class FirebaseInit {
  FirebaseInit._();

  static bool _initialized = false;
  static bool _available = false;
  static String? _lastError;

  /// Whether Firebase has been initialized successfully on this process.
  static bool get available => _available;

  /// The most recent init error, if any (for surfacing in the sync UI).
  static String? get lastError => _lastError;

  /// Initialize Firebase. Safe to call multiple times.
  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      _available = false;
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('FirebaseInit: initialization skipped -> $e');
        debugPrint('$st');
      }
      return;
    }

    try {
      // Enable Firestore offline persistence. Mobile has this on by default
      // but we set an explicit unlimited cache so pending writes never get
      // evicted while the device is offline.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FirebaseInit: could not tune Firestore settings -> $e');
      }
    }

    _available = true;
    if (kDebugMode) {
      debugPrint('FirebaseInit: Firebase ready.');
    }
  }
}
