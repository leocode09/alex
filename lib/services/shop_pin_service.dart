import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud/firebase_init.dart';
import 'cloud/firestore_paths.dart';

/// Firestore-backed shop PIN config shared from owner to staff devices.
class ShopPinService {
  ShopPinService._internal();
  static final ShopPinService _instance = ShopPinService._internal();
  factory ShopPinService() => _instance;

  static const String settingsDocId = 'pin';
  static const String _cachePrefsPrefix = 'shop_pin_config_';

  /// Last fetched config per shop, so router redirects never need a
  /// blocking network round-trip. Backed by SharedPreferences so it
  /// survives restarts; refreshed in the background after each fetch.
  final Map<String, Map<String, dynamic>> _memCache = {};

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
      final data = snap.data();
      if (data != null) {
        await _storeCachedConfig(shopId, data);
      }
      return data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPinService.fetchConfig error: $e');
      }
      return null;
    }
  }

  /// Returns the cached copy of the last fetched config for [shopId]
  /// (memory first, then SharedPreferences) without touching the
  /// network. Returns null when nothing was ever fetched.
  Future<Map<String, dynamic>?> cachedConfig(String shopId) async {
    final mem = _memCache[shopId];
    if (mem != null) {
      return mem;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefsPrefix$shopId');
      if (raw == null) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _memCache[shopId] = decoded;
        return decoded;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPinService.cachedConfig error: $e');
      }
    }
    return null;
  }

  Future<void> _storeCachedConfig(
    String shopId,
    Map<String, dynamic> config,
  ) async {
    _memCache[shopId] = config;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefsPrefix$shopId', jsonEncode(config));
    } catch (e) {
      // Best-effort: a non-JSON-encodable field or prefs failure only
      // costs the restart-survival of the cache, never correctness.
      if (kDebugMode) {
        debugPrint('ShopPinService cache persist error: $e');
      }
    }
  }

  /// Returns the owner's PIN + preference map when configured.
  /// Performs a blocking Firestore read; prefer [loadCachedForStaff]
  /// on latency-sensitive paths.
  Future<({String pin, Map<String, bool> preferences})?> loadForStaff(
    String shopId,
  ) async {
    return _parseStaffConfig(await fetchConfig(shopId));
  }

  /// Same as [loadForStaff] but served purely from the local cache —
  /// never hits the network. Returns null when no config was cached.
  Future<({String pin, Map<String, bool> preferences})?> loadCachedForStaff(
    String shopId,
  ) async {
    return _parseStaffConfig(await cachedConfig(shopId));
  }

  ({String pin, Map<String, bool> preferences})? _parseStaffConfig(
    Map<String, dynamic>? config,
  ) {
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

  Future<bool> publish({
    required String shopId,
    required String pin,
    required Map<String, bool> preferences,
  }) async {
    if (!FirebaseInit.available) {
      return false;
    }
    if (pin.length != 4) {
      return false;
    }
    try {
      final config = <String, dynamic>{
        'pin': pin,
        'preferences': preferences,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _doc(shopId).set(config, SetOptions(merge: true));
      await _storeCachedConfig(shopId, config);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopPinService.publish error: $e');
      }
      return false;
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
