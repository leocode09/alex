import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'cloud/firebase_init.dart';
import 'cloud/firestore_paths.dart';
import 'pin_service.dart';

/// Syncs the shop owner's PIN + preference map to Firestore so staff
/// devices inherit the same protection rules without creating their own.
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

  /// Pull the owner's PIN config onto this device for a staff member.
  /// Returns true when a shop PIN was applied locally.
  Future<bool> applyForStaff(String shopId) async {
    final config = await fetchConfig(shopId);
    if (config == null) {
      return false;
    }
    final pin = config['pin'];
    if (pin is! String || pin.length != 4) {
      return false;
    }
    final preferences = _decodePreferences(config['preferences']);
    await PinService().importShopOwnerPin(
      pin: pin,
      preferences: preferences,
    );
    return true;
  }

  /// Push the locally configured PIN + preferences to the shop doc.
  Future<void> publishFromLocal(String shopId) async {
    if (!FirebaseInit.available) {
      return;
    }
    final pinService = PinService();
    final pin = await pinService.getStoredPin();
    if (pin == null) {
      return;
    }
    final preferences = await pinService.getPinPreferences();
    try {
      await _doc(shopId).set({
        'pin': pin,
        'preferences': preferences,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPinService.publishFromLocal error: $e');
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

// PinService reads SharedPreferences directly for publish; expose import there.
