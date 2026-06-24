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
      // Enable Firestore offline persistence on mobile/desktop (offline-
      // first): an explicit unlimited cache so pending writes are never
      // evicted while the device is offline.
      //
      // On WEB, do NOT enable IndexedDB persistence. Combined with the
      // firebase-js-sdk watch streams it triggers "INTERNAL ASSERTION
      // FAILED: Unexpected state" crashes — especially here, where the
      // admin panel runs a *second* Firestore instance with concurrent
      // listeners against the same project. Web is online-first, so an
      // in-memory cache is the correct trade and removes the crash.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: !kIsWeb,
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
