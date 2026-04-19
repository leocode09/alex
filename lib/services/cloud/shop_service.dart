import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin/device_heartbeat_service.dart';
import '../admin/license_service.dart';
import 'firebase_init.dart';
import 'firestore_paths.dart';

class ShopInfo {
  final String id;
  final String code;
  final String name;
  final String ownerUid;
  final DateTime createdAt;

  const ShopInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'ownerUid': ownerUid,
        'createdAt': createdAt.toIso8601String(),
      };
}

class ShopResult {
  final bool success;
  final String message;
  final ShopInfo? shop;

  const ShopResult._(
      {required this.success, required this.message, this.shop});

  factory ShopResult.ok(String message, ShopInfo shop) =>
      ShopResult._(success: true, message: message, shop: shop);

  factory ShopResult.fail(String message) =>
      ShopResult._(success: false, message: message);
}

/// Outcome of [ShopService.ensureAuth]. Exposes the underlying Firebase error
/// (code + message) so the UI can show something actionable instead of a
/// generic "check your internet connection".
class AuthResult {
  final String? uid;
  final String? errorCode;
  final String? errorMessage;

  const AuthResult.ok(String this.uid)
      : errorCode = null,
        errorMessage = null;

  const AuthResult.fail({
    required String code,
    required String message,
  })  : uid = null,
        errorCode = code,
        errorMessage = message;

  bool get success => uid != null;

  /// Human-readable, actionable description for the UI/logs.
  String describe() {
    final code = errorCode;
    final msg = errorMessage ?? 'Unknown error';
    switch (code) {
      case 'operation-not-allowed':
        return 'Anonymous sign-in is disabled in the Firebase project. '
            'Open Firebase Console → Authentication → Sign-in method and '
            'enable "Anonymous".';
      case 'network-request-failed':
        return 'No internet connection reached Firebase. Check Wi-Fi / data '
            'and try again.';
      case 'admin-restricted-operation':
        return 'Anonymous sign-in is blocked by an admin policy on the '
            'Firebase project.';
      case 'app-not-authorized':
      case 'api-key-not-valid':
        return 'This app\'s Firebase configuration is rejected by the '
            'project (bad API key / SHA). Re-run `flutterfire configure`.';
      case null:
        return msg;
      default:
        return '[$code] $msg';
    }
  }
}

/// Manages the device's membership in a cloud "shop" (tenant scope for
/// Firestore sync).
///
/// Flow:
///   - On first run: shop is null; UI offers Create Shop or Join Shop.
///   - Create generates a unique 6-char code and a new `/shops/{id}` doc.
///   - Join enters a code, queries `/shops` by code, adds this device's
///     Firebase UID to `/shops/{id}/members/{uid}`.
///   - The resolved `shopId` is persisted locally under `cloud_shop_id`.
class ShopService {
  ShopService._internal();

  static final ShopService _instance = ShopService._internal();

  factory ShopService() => _instance;

  static const String shopIdPrefsKey = 'cloud_shop_id';
  static const String shopNamePrefsKey = 'cloud_shop_name';
  static const String shopCodePrefsKey = 'cloud_shop_code';
  static const int _codeLength = 6;

  // Excludes ambiguous characters: 0, O, I, l, 1
  static const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  final Random _random = Random.secure();

  String? _cachedShopId;
  String? _cachedShopName;
  String? _cachedShopCode;

  String? get cachedShopId => _cachedShopId;
  String? get cachedShopName => _cachedShopName;
  String? get cachedShopCode => _cachedShopCode;

  Future<void> loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedShopId = prefs.getString(shopIdPrefsKey);
    _cachedShopName = prefs.getString(shopNamePrefsKey);
    _cachedShopCode = prefs.getString(shopCodePrefsKey);
  }

  /// Returns the currently joined shop, if any.
  Future<ShopInfo?> currentShop() async {
    if (!FirebaseInit.available) {
      return null;
    }
    await loadCache();
    final id = _cachedShopId;
    if (id == null || id.isEmpty) {
      return null;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(id)
          .get();
      if (!snap.exists) {
        return null;
      }
      return _shopFromDoc(snap);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopService.currentShop error: $e');
      }
      return null;
    }
  }

  /// Ensures the device is signed in anonymously. Returns the resolved UID
  /// or null if auth is unavailable (e.g. Firebase not initialized).
  ///
  /// Prefer [ensureAuthDetailed] in new code — it exposes the Firebase error
  /// code so the UI can surface an actionable message.
  Future<String?> ensureAuth() async {
    final result = await ensureAuthDetailed();
    return result.uid;
  }

  /// Like [ensureAuth] but returns the full error (code + message) when
  /// sign-in fails, so the caller can distinguish e.g. "anonymous auth
  /// disabled in Firebase" from a real network outage.
  Future<AuthResult> ensureAuthDetailed() async {
    if (!FirebaseInit.available) {
      return const AuthResult.fail(
        code: 'firebase-not-initialized',
        message: 'Firebase is not initialized on this build.',
      );
    }
    try {
      final auth = FirebaseAuth.instance;
      final current = auth.currentUser;
      if (current != null) {
        return AuthResult.ok(current.uid);
      }
      final cred = await auth.signInAnonymously();
      final uid = cred.user?.uid;
      if (uid == null) {
        return const AuthResult.fail(
          code: 'no-uid',
          message: 'Firebase returned no user id.',
        );
      }
      return AuthResult.ok(uid);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ShopService.ensureAuth FirebaseAuthException: '
          '${e.code} — ${e.message}',
        );
      }
      return AuthResult.fail(
        code: e.code,
        message: e.message ?? 'Firebase auth error.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopService.ensureAuth error: $e');
      }
      return AuthResult.fail(code: 'unknown', message: e.toString());
    }
  }

  Future<ShopResult> createShop({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return ShopResult.fail('Shop name is required.');
    }
    if (!FirebaseInit.available) {
      return ShopResult.fail(
        'Cloud is not configured. Run `flutterfire configure` first.',
      );
    }

    final auth = await ensureAuthDetailed();
    final uid = auth.uid;
    if (uid == null) {
      return ShopResult.fail('Sign-in failed: ${auth.describe()}');
    }

    try {
      final db = FirebaseFirestore.instance;
      final code = await _generateUniqueCode();
      final shopRef =
          db.collection(FirestorePaths.shopsCollection).doc();
      final now = DateTime.now();

      await shopRef.set({
        'code': code,
        'name': trimmed,
        'ownerUid': uid,
        'createdAt': now.toIso8601String(),
        'memberCount': 1,
      });
      await shopRef
          .collection(FirestorePaths.membersSubcollection)
          .doc(uid)
          .set({
        'role': 'owner',
        'joinedAt': now.toIso8601String(),
      });

      final shop = ShopInfo(
        id: shopRef.id,
        code: code,
        name: trimmed,
        ownerUid: uid,
        createdAt: now,
      );
      await _persistCache(shop);
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      return ShopResult.ok('Shop created. Code: $code', shop);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopService.createShop error: $e');
      }
      return ShopResult.fail('Failed to create shop: $e');
    }
  }

  Future<ShopResult> joinShop({required String code}) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length != _codeLength) {
      return ShopResult.fail('Shop code must be $_codeLength characters.');
    }
    if (!FirebaseInit.available) {
      return ShopResult.fail(
        'Cloud is not configured. Run `flutterfire configure` first.',
      );
    }

    final auth = await ensureAuthDetailed();
    final uid = auth.uid;
    if (uid == null) {
      return ShopResult.fail('Sign-in failed: ${auth.describe()}');
    }

    try {
      final db = FirebaseFirestore.instance;
      final query = await db
          .collection(FirestorePaths.shopsCollection)
          .where('code', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return ShopResult.fail('No shop found with code $trimmed.');
      }

      final shopDoc = query.docs.first;
      final shop = _shopFromDoc(shopDoc);

      final now = DateTime.now();
      await shopDoc.reference
          .collection(FirestorePaths.membersSubcollection)
          .doc(uid)
          .set({
        'role': 'member',
        'joinedAt': now.toIso8601String(),
      }, SetOptions(merge: true));

      await _persistCache(shop);
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      return ShopResult.ok('Joined shop "${shop.name}".', shop);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopService.joinShop error: $e');
      }
      return ShopResult.fail('Failed to join shop: $e');
    }
  }

  Future<void> leaveShop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(shopIdPrefsKey);
    await prefs.remove(shopNamePrefsKey);
    await prefs.remove(shopCodePrefsKey);
    _cachedShopId = null;
    _cachedShopName = null;
    _cachedShopCode = null;
    unawaited(DeviceHeartbeatService().refreshShopMembership());
    unawaited(LicenseService().refresh());
  }

  Future<void> _persistCache(ShopInfo shop) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(shopIdPrefsKey, shop.id);
    await prefs.setString(shopNamePrefsKey, shop.name);
    await prefs.setString(shopCodePrefsKey, shop.code);
    _cachedShopId = shop.id;
    _cachedShopName = shop.name;
    _cachedShopCode = shop.code;
  }

  Future<String> _generateUniqueCode() async {
    final db = FirebaseFirestore.instance;
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = _randomCode();
      final existing = await db
          .collection(FirestorePaths.shopsCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        return code;
      }
    }
    // Extremely unlikely: fall back to a longer code with the same alphabet.
    return _randomCode(length: _codeLength + 2);
  }

  String _randomCode({int length = _codeLength}) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_codeAlphabet[_random.nextInt(_codeAlphabet.length)]);
    }
    return buffer.toString();
  }

  ShopInfo _shopFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ShopInfo(
      id: doc.id,
      code: (data['code'] as String? ?? '').toUpperCase(),
      name: (data['name'] as String? ?? 'Shop'),
      ownerUid: (data['ownerUid'] as String? ?? ''),
      createdAt: _parseDate(data['createdAt']),
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
