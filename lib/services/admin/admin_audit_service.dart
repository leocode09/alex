import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../cloud/firestore_paths.dart';
import 'admin_auth_service.dart';

/// Target of an audited change.
enum AuditTargetType { shop, device }

/// Writes a structured audit entry under the target's `auditLog`
/// subcollection whenever an admin changes a shop or device doc.
///
/// Entries are admin-only (enforced by Firestore rules) and are never
/// mutated after creation. The diff calculation happens client-side so
/// we only store the keys an admin actually changed, plus the old/new
/// values — never the whole doc.
class AdminAuditService {
  AdminAuditService._internal();
  static final AdminAuditService _instance = AdminAuditService._internal();
  factory AdminAuditService() => _instance;

  final AdminAuthService _auth = AdminAuthService();

  /// Record a change for a shop. [before] is the doc state read prior
  /// to the write, [after] is the merged state the admin is about to
  /// persist. The service writes only the diff.
  Future<void> recordShopChange({
    required String shopId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    required String action,
  }) async {
    await _record(
      targetType: AuditTargetType.shop,
      targetId: shopId,
      path: FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection('auditLog'),
      before: before,
      after: after,
      action: action,
    );
  }

  /// Record a change for a device.
  Future<void> recordDeviceChange({
    required String installId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    required String action,
  }) async {
    await _record(
      targetType: AuditTargetType.device,
      targetId: installId,
      path: FirebaseFirestore.instance
          .collection(FirestorePaths.devicesCollection)
          .doc(installId)
          .collection('auditLog'),
      before: before,
      after: after,
      action: action,
    );
  }

  /// Direct / free-form entry for bulk actions where there isn't a
  /// meaningful before/after (e.g. "Bulk blocked 5 devices").
  Future<void> recordFreeform({
    required AuditTargetType targetType,
    required String targetId,
    required String action,
    Map<String, dynamic> details = const {},
  }) async {
    final db = _auth.db;
    if (db == null) return;
    try {
      final coll = targetType == AuditTargetType.shop
          ? db
              .collection(FirestorePaths.shopsCollection)
              .doc(targetId)
              .collection('auditLog')
          : db
              .collection(FirestorePaths.devicesCollection)
              .doc(targetId)
              .collection('auditLog');
      await coll.add({
        'at': FieldValue.serverTimestamp(),
        'atIso': DateTime.now().toIso8601String(),
        'actorUid': _auth.currentUid,
        'actorEmail': _auth.currentEmail,
        'action': action,
        'targetType':
            targetType == AuditTargetType.shop ? 'shop' : 'device',
        'targetId': targetId,
        'changes': const <String, dynamic>{},
        'details': details,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AdminAuditService.recordFreeform failed: $e');
      }
    }
  }

  Future<void> _record({
    required AuditTargetType targetType,
    required String targetId,
    required CollectionReference<Map<String, dynamic>> path,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    required String action,
  }) async {
    final db = _auth.db;
    if (db == null) return;

    // Use the admin-bound Firestore instance so rules see the admin uid.
    final adminPath = _adminPath(targetType, targetId);
    if (adminPath == null) return;

    final changes = _diff(before, after);
    if (changes.isEmpty) return;

    try {
      await adminPath.add({
        'at': FieldValue.serverTimestamp(),
        'atIso': DateTime.now().toIso8601String(),
        'actorUid': _auth.currentUid,
        'actorEmail': _auth.currentEmail,
        'action': action,
        'targetType':
            targetType == AuditTargetType.shop ? 'shop' : 'device',
        'targetId': targetId,
        'changes': changes,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AdminAuditService._record failed: $e');
      }
    }
  }

  CollectionReference<Map<String, dynamic>>? _adminPath(
    AuditTargetType targetType,
    String targetId,
  ) {
    final db = _auth.db;
    if (db == null) return null;
    if (targetType == AuditTargetType.shop) {
      return db
          .collection(FirestorePaths.shopsCollection)
          .doc(targetId)
          .collection('auditLog');
    }
    return db
        .collection(FirestorePaths.devicesCollection)
        .doc(targetId)
        .collection('auditLog');
  }

  /// Computes a minimal diff between two shallow-ish maps. For maps
  /// named `featureFlags`, `featureOverrides`, or `pinForcedFlags` the
  /// diff is taken at per-feature granularity so "turned off Sales"
  /// doesn't log the whole flag map.
  Map<String, Map<String, dynamic>> _diff(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    const nestedMapKeys = {
      'featureFlags',
      'featureOverrides',
      'pinForcedFlags',
    };
    final keys = <String>{...before.keys, ...after.keys};
    final diff = <String, Map<String, dynamic>>{};
    for (final k in keys) {
      if (nestedMapKeys.contains(k)) {
        final b = before[k];
        final a = after[k];
        final bMap = b is Map ? b.cast<String, dynamic>() : const {};
        final aMap = a is Map ? a.cast<String, dynamic>() : const {};
        final subKeys = <String>{...bMap.keys, ...aMap.keys};
        for (final sk in subKeys) {
          final bv = bMap[sk];
          final av = aMap[sk];
          if (!_valuesEqual(bv, av)) {
            diff['$k.$sk'] = {
              'old': _sanitize(bv),
              'new': _sanitize(av),
            };
          }
        }
        continue;
      }
      final bv = before[k];
      final av = after[k];
      if (!_valuesEqual(bv, av)) {
        diff[k] = {'old': _sanitize(bv), 'new': _sanitize(av)};
      }
    }
    return diff;
  }

  bool _valuesEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a is Timestamp && b is Timestamp) return a.compareTo(b) == 0;
    return a == b;
  }

  dynamic _sanitize(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), _sanitize(v)),
      );
    }
    if (value is List) {
      return value.map(_sanitize).toList();
    }
    return value;
  }
}
