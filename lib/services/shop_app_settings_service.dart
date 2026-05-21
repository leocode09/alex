import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_app_settings.dart';
import 'bonus_rule_service.dart';
import 'cloud/account_service.dart';
import 'cloud/firebase_init.dart';
import 'cloud/firestore_paths.dart';

/// Loads/saves shop settings locally first, then syncs to Firestore/LAN peers.
class ShopAppSettingsService {
  ShopAppSettingsService._internal();
  static final ShopAppSettingsService _instance =
      ShopAppSettingsService._internal();
  factory ShopAppSettingsService() => _instance;

  static const String settingsDocId = 'app';
  static const String _updatedAtKey = 'shop_app_settings_updated_at';

  DocumentReference<Map<String, dynamic>> _doc(String shopId) {
    return FirebaseFirestore.instance
        .collection(FirestorePaths.shopsCollection)
        .doc(shopId)
        .collection(FirestorePaths.settingsSubcollection)
        .doc(settingsDocId);
  }

  /// Only the shop owner may publish shop-wide settings. Staff inherit
  /// the owner's values from cloud/LAN sync.
  Future<bool> canEditShopSettings() async {
    final account = AccountService().current;
    if (account.firebaseUnavailable) {
      return true;
    }
    return account.isOwner;
  }

  Future<ShopAppSettings> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? receipt;
    Map<String, dynamic>? tax;
    Map<String, dynamic>? bonus;

    final receiptJson = prefs.getString('receipt_settings');
    if (receiptJson != null) {
      receipt = Map<String, dynamic>.from(jsonDecode(receiptJson) as Map);
    }
    final taxJson = prefs.getString('tax_settings');
    if (taxJson != null) {
      tax = Map<String, dynamic>.from(jsonDecode(taxJson) as Map);
    }
    bonus = {
      'enabled': prefs.getBool('bonus_rule_enabled') ?? BonusRule.defaults.enabled,
      'windowDays':
          prefs.getInt('bonus_rule_window_days') ?? BonusRule.defaults.windowDays,
      'thresholdAmount': prefs.getDouble('bonus_rule_threshold') ??
          BonusRule.defaults.thresholdAmount,
      'bonusAmount':
          prefs.getDouble('bonus_rule_bonus') ?? BonusRule.defaults.bonusAmount,
    };

    final updatedAt = DateTime.tryParse(
          prefs.getString(_updatedAtKey) ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return ShopAppSettings(
      receipt: receipt,
      tax: tax,
      bonus: bonus,
      updatedAt: updatedAt,
    );
  }

  Future<ShopAppSettings> snapshotForSync() async {
    final local = await loadLocal();
    if (local.updatedAt.millisecondsSinceEpoch > 0) {
      return local;
    }
    return ShopAppSettings(
      receipt: local.receipt,
      tax: local.tax,
      bonus: local.bonus,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _writeLocal(ShopAppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.receipt != null) {
      await prefs.setString(
        'receipt_settings',
        jsonEncode(settings.receipt),
      );
    }
    if (settings.tax != null) {
      await prefs.setString(
        'tax_settings',
        jsonEncode(settings.tax),
      );
    }
    if (settings.bonus != null) {
      final bonus = settings.bonus!;
      await prefs.setBool(
        'bonus_rule_enabled',
        bonus['enabled'] as bool? ?? BonusRule.defaults.enabled,
      );
      await prefs.setInt(
        'bonus_rule_window_days',
        (bonus['windowDays'] as num?)?.toInt() ?? BonusRule.defaults.windowDays,
      );
      await prefs.setDouble(
        'bonus_rule_threshold',
        (bonus['thresholdAmount'] as num?)?.toDouble() ??
            BonusRule.defaults.thresholdAmount,
      );
      await prefs.setDouble(
        'bonus_rule_bonus',
        (bonus['bonusAmount'] as num?)?.toDouble() ??
            BonusRule.defaults.bonusAmount,
      );
    }
    await prefs.setString(
      _updatedAtKey,
      settings.updatedAt.toIso8601String(),
    );
  }

  /// Applies incoming settings when they are newer than local (offline-first).
  Future<bool> mergeIncoming(ShopAppSettings incoming) async {
    if (incoming.isEmpty) {
      return false;
    }
    final local = await loadLocal();
    if (!incoming.updatedAt.isAfter(local.updatedAt)) {
      return false;
    }
    await _writeLocal(incoming);
    return true;
  }

  Future<void> touchLocal({DateTime? updatedAt}) async {
    if (!await canEditShopSettings()) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _updatedAtKey,
      (updatedAt ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<void> publishToCloud(String shopId) async {
    if (!FirebaseInit.available || !await canEditShopSettings()) {
      return;
    }
    final settings = await snapshotForSync();
    try {
      await _doc(shopId).set({
        ...settings.toJson(),
        'cloudUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopAppSettingsService.publishToCloud error: $e');
      }
    }
  }

  Future<ShopAppSettings?> fetchFromCloud(String shopId) async {
    if (!FirebaseInit.available) {
      return null;
    }
    try {
      final snap = await _doc(shopId).get();
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      return ShopAppSettings.fromJson(snap.data()!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopAppSettingsService.fetchFromCloud error: $e');
      }
      return null;
    }
  }

  Future<bool> pullFromCloud(String shopId) async {
    final remote = await fetchFromCloud(shopId);
    if (remote == null) {
      return false;
    }
    return mergeIncoming(remote);
  }
}
