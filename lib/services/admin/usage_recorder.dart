import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/firebase_init.dart';
import '../cloud/firestore_paths.dart';
import '../cloud/shop_service.dart';
import 'install_id_service.dart';

/// Records per-day usage counters for the super admin dashboard.
///
/// Events are first accumulated in SharedPreferences (so a brief offline
/// burst doesn't lose data) and flushed to Firestore periodically. Flush
/// failures are silent — the local buffer is kept and retried on the
/// next flush tick.
///
/// Each flush increments two documents:
///   /devices/{installId}/usageDaily/{YYYY-MM-DD}
///   /shops/{shopId}/usageDaily/{YYYY-MM-DD}   (if the device joined a shop)
class UsageRecorder {
  UsageRecorder._internal();
  static final UsageRecorder _instance = UsageRecorder._internal();
  factory UsageRecorder() => _instance;

  static const Duration _flushInterval = Duration(seconds: 30);
  static const String _pendingPrefsKey = 'usage_pending_events';

  // Counter keys also written into Firestore.
  static const String kAppOpens = 'appOpens';
  static const String kSalesCount = 'salesCount';
  static const String kSalesAmountCents = 'salesAmountCents';
  static const String kReceiptsPrinted = 'receiptsPrinted';
  static const String kProductsEdited = 'productsEdited';

  final ShopService _shopService = ShopService();

  Timer? _timer;
  bool _flushing = false;

  Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) {
      unawaited(_flush());
    });
    unawaited(_flush());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  // ---------- public event API ----------

  Future<void> recordAppOpen() =>
      _bump(counters: {kAppOpens: 1});

  Future<void> recordSale({required double amount}) {
    final cents = (amount * 100).round();
    return _bump(counters: {
      kSalesCount: 1,
      kSalesAmountCents: cents < 0 ? 0 : cents,
    });
  }

  Future<void> recordReceiptPrinted() =>
      _bump(counters: {kReceiptsPrinted: 1});

  Future<void> recordProductEdited() =>
      _bump(counters: {kProductsEdited: 1});

  // ---------- internals ----------

  Future<void> _bump({required Map<String, int> counters}) async {
    if (counters.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = _readPending(prefs);
    final key = _dayKey(DateTime.now());
    final bucket = Map<String, int>.from(pending[key] ?? const {});
    counters.forEach((k, v) {
      bucket[k] = (bucket[k] ?? 0) + v;
    });
    pending[key] = bucket;
    await _writePending(prefs, pending);

    // Best-effort eager flush so live updates reach admins quickly.
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_flushing) return;
    if (!FirebaseInit.available) return;

    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = _readPending(prefs);
      if (pending.isEmpty) {
        return;
      }
      final installId = await InstallIdService.ensure();
      final uid = await _shopService.ensureAuth();
      if (uid == null) {
        return;
      }
      final shopId = _shopService.cachedShopId;

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (final entry in pending.entries) {
        final day = entry.key;
        final counters = entry.value;
        if (counters.isEmpty) continue;
        final deviceRef = db
            .collection(FirestorePaths.devicesCollection)
            .doc(installId)
            .collection(FirestorePaths.usageDailySubcollection)
            .doc(day);

        final deviceUpdate = <String, dynamic>{
          'day': day,
          'installId': installId,
          'ownerUid': uid,
          'shopId': shopId,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        };
        counters.forEach((k, v) {
          deviceUpdate[k] = FieldValue.increment(v);
        });
        batch.set(deviceRef, deviceUpdate, SetOptions(merge: true));

        if (shopId != null && shopId.isNotEmpty) {
          final shopRef = db
              .collection(FirestorePaths.shopsCollection)
              .doc(shopId)
              .collection(FirestorePaths.usageDailySubcollection)
              .doc(day);
          final shopUpdate = <String, dynamic>{
            'day': day,
            'shopId': shopId,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          };
          counters.forEach((k, v) {
            shopUpdate[k] = FieldValue.increment(v);
          });
          batch.set(shopRef, shopUpdate, SetOptions(merge: true));
        }
      }

      await batch.commit();
      // Only clear after a successful commit.
      await _writePending(prefs, const {});
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('UsageRecorder flush failed: $e\n$st');
      }
    } finally {
      _flushing = false;
    }
  }

  Map<String, Map<String, int>> _readPending(SharedPreferences prefs) {
    final raw = prefs.getString(_pendingPrefsKey);
    if (raw == null || raw.isEmpty) return <String, Map<String, int>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, int>>{};
      final result = <String, Map<String, int>>{};
      decoded.forEach((k, v) {
        if (k is String && v is Map) {
          final counters = <String, int>{};
          v.forEach((ck, cv) {
            if (ck is String && cv is num) {
              counters[ck] = cv.toInt();
            }
          });
          if (counters.isNotEmpty) {
            result[k] = counters;
          }
        }
      });
      return result;
    } catch (_) {
      return <String, Map<String, int>>{};
    }
  }

  Future<void> _writePending(
    SharedPreferences prefs,
    Map<String, Map<String, int>> value,
  ) async {
    if (value.isEmpty) {
      await prefs.remove(_pendingPrefsKey);
      return;
    }
    await prefs.setString(_pendingPrefsKey, jsonEncode(value));
  }

  static String _dayKey(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
