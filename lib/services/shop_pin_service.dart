import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'cloud/firebase_init.dart';
import 'cloud/firestore_paths.dart';

/// Firestore-backed shop PIN config shared from owner to staff devices.
class ShopPinService {
  ShopPinService._internal();
  static final ShopPinService _instance = ShopPinService._internal();
  factory ShopPinService() => _instance;

  static const String settingsDocId = 'pin';

  DocumentReference<Map<String, dynamic>> _doc(String shopId) {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.shopsCollection)
        .doc(shopId)
        .collection(FirestorePaths.settingsSubcollection)
        .doc(settingsDocId);
  }

  Future<Map<String, dynamic>?> fetchConfig(String shopId) async {
    if (!FirebaseInit.available) {
      return null;
    }
    try {
      final snap = await _doc(shopId).get();
      if (!snap.exists) {
        return null;
      }
      return snap.data();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPinService.fetchConfig error: $e');
      }
      return null;
    }
  }

  /// Returns the owner's PIN + preference map when configured.
  Future<({String pin, Map<String, bool> preferences})?> loadForStaff(
    String shopId,
  ) async {
    final config = await fetchConfig(shopId);
    if (config == null) {
      return null;
    }
    final pin = config['pin'];
    if (pin is! String || pin.length != 4) {
      return null;
    }
    return (
      pin: pin,
      preferences: _decodePreferences(config['preferences']),
    );
  }

  Future<void> publish({
    required String shopId,
    required String pin,
    required Map<String, bool> preferences,
  }) async {
    if (!FirebaseInit.available) {
      return;
    }
    try {
      await _doc(shopId).set({
        'pin': pin,
        'preferences': preferences,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPinService.publish error: $e');
      }
    }
  }

  Map<String, bool> _decodePreferences(Object? raw) {
    if (raw is Map) {
      final out = <String, bool>{};
      for (final entry in raw.entries) {
        if (entry.value is bool) {
          out['${entry.key}'] = entry.value as bool;
        }
      }
      return out;
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return _decodePreferences(decoded);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }
}
