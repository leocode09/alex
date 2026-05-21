import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/account_state.dart';
import '../admin/device_heartbeat_service.dart';
import '../admin/license_service.dart';
import 'firebase_init.dart';
import 'firestore_paths.dart';
import 'shop_service.dart';

/// Drives the new business-approval workflow.
///
/// The service:
///
///   - watches `/shops/{cachedShopId}` and
///     `/shops/{cachedShopId}/members/{currentUid}` and reduces them
///     into an [AccountState] the rest of the app consumes via
///     `accountStateProvider`,
///   - lets a business owner submit a new business registration
///     (`/shops/{id}` with `approvalStatus: pendingSystemAdmin`),
///   - lets a staff member search for approved businesses and submit a
///     join request (`/shops/{id}/members/{uid}` with
///     `approvalStatus: pendingOwner`),
///   - lets an approved owner approve / reject pending staff,
///   - lets a rejected or pending request be cleared so the user can
///     start over.
///
/// All writes degrade gracefully when Firebase is unavailable.
class AccountService {
  AccountService._internal();
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;

  final ShopService _shopService = ShopService();

  StreamController<AccountState>? _controller;
  AccountState _current = AccountState.unknown;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _shopSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;

  String? _attachedShopId;
  String? _attachedUid;
  Map<String, dynamic>? _lastShop;
  Map<String, dynamic>? _lastMember;
  bool _attaching = false;

  AccountState get current => _current;

  // ---------- stream ----------

  Stream<AccountState> watch() {
    _controller ??= StreamController<AccountState>.broadcast(
      onListen: _kickstart,
    );
    scheduleMicrotask(() {
      final c = _controller;
      if (c != null && !c.isClosed) {
        c.add(_current);
      }
    });
    return _controller!.stream;
  }

  void _kickstart() {
    unawaited(_reattach());
  }

  /// Call after the user creates / joins / leaves a shop so the
  /// listeners reattach to the new shop id.
  Future<void> refresh() => _reattach();

  Future<void> _reattach() async {
    if (_attaching) return;
    _attaching = true;
    try {
      if (!FirebaseInit.available) {
        _emit(AccountState.firebaseDown);
        return;
      }

      await _shopService.loadCache();
      final shopId = _shopService.cachedShopId;
      final uid = await _shopService.ensureAuth();

      if (uid == null) {
        _emit(AccountState.firebaseDown);
        return;
      }

      if (shopId == null || shopId.isEmpty) {
        await _detach();
        _emit(AccountState.noAccount);
        return;
      }

      var activeShopId = await _resolveShopId(shopId, uid);

      if (_attachedShopId != activeShopId || _attachedUid != uid) {
        await _detach();
        _attachedShopId = activeShopId;
        _attachedUid = uid;
        _shopSub = FirebaseFirestore.instance
            .collection(FirestorePaths.shopsCollection)
            .doc(activeShopId)
            .snapshots()
            .listen(
          (doc) {
            _lastShop = doc.exists ? doc.data() : null;
            _emitMerged();
          },
          onError: (e) {
            if (kDebugMode) {
              debugPrint('AccountService shop listener error: $e');
            }
          },
        );
        _memberSub = FirebaseFirestore.instance
            .collection(FirestorePaths.shopsCollection)
            .doc(activeShopId)
            .collection(FirestorePaths.membersSubcollection)
            .doc(uid)
            .snapshots()
            .listen(
          (doc) {
            _lastMember = doc.exists ? doc.data() : null;
            _emitMerged();
          },
          onError: (e) {
            if (kDebugMode) {
              debugPrint('AccountService member listener error: $e');
            }
          },
        );
      }

      await _fetchLatestDocs(activeShopId, uid);
      _emitMerged();
    } finally {
      _attaching = false;
    }
  }

  Future<void> _detach() async {
    await _shopSub?.cancel();
    _shopSub = null;
    await _memberSub?.cancel();
    _memberSub = null;
    _attachedShopId = null;
    _attachedUid = null;
    _lastShop = null;
    _lastMember = null;
  }

  /// Force-read the latest shop + member docs. The pending-approval
  /// screen's Refresh button relies on this because re-attaching
  /// listeners alone does not re-fetch when ids are unchanged.
  Future<void> _fetchLatestDocs(String shopId, String uid) async {
    try {
      final db = FirebaseFirestore.instance;
      final shopSnap =
          await db.collection(FirestorePaths.shopsCollection).doc(shopId).get();
      _lastShop = shopSnap.exists ? shopSnap.data() : null;
      final memberSnap = await db
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection(FirestorePaths.membersSubcollection)
          .doc(uid)
          .get();
      _lastMember = memberSnap.exists ? memberSnap.data() : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._fetchLatestDocs error: $e');
      }
    }
  }

  /// If this device cached a shop id/code that never landed in Firestore
  /// (or a duplicate registration was started), re-bind to the owner's
  /// real approved business when one exists.
  Future<String> _resolveShopId(String cachedShopId, String uid) async {
    try {
      final db = FirebaseFirestore.instance;
      final cachedSnap = await db
          .collection(FirestorePaths.shopsCollection)
          .doc(cachedShopId)
          .get();
      final cachedStatus = cachedSnap.exists
          ? ((cachedSnap.data()?[AccountApproval.fieldStatus] as String?) ??
              AccountApproval.statusApproved)
          : null;

      if (cachedSnap.exists &&
          cachedStatus == AccountApproval.statusApproved) {
        return cachedShopId;
      }

      final owned = await db
          .collection(FirestorePaths.shopsCollection)
          .where('ownerUid', isEqualTo: uid)
          .limit(5)
          .get();
      if (owned.docs.isEmpty) {
        return cachedShopId;
      }

      DocumentSnapshot<Map<String, dynamic>>? approved;
      DocumentSnapshot<Map<String, dynamic>>? pending;
      for (final doc in owned.docs) {
        final status =
            (doc.data()[AccountApproval.fieldStatus] as String?) ??
                AccountApproval.statusApproved;
        if (status == AccountApproval.statusApproved) {
          approved = doc;
          break;
        }
        pending ??= doc;
      }

      final target = approved ?? pending;
      if (target == null) {
        return cachedShopId;
      }

      if (target.id == cachedShopId && cachedSnap.exists) {
        return cachedShopId;
      }

      final data = target.data()!;
      await _shopService.persistShopCache(
        id: target.id,
        code: (data['code'] as String?) ?? '',
        name: (data['name'] as String?) ?? 'Business',
      );
      return target.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._resolveShopId error: $e');
      }
      return cachedShopId;
    }
  }

  void _emitMerged() {
    final shopId = _attachedShopId;
    if (shopId == null || shopId.isEmpty) {
      _emit(AccountState.noAccount);
      return;
    }
    final shop = _lastShop;
    if (shop == null) {
      // Still loading or temporarily unreadable — keep the user on the
      // pending gate using cached shop identity instead of bouncing
      // them back to onboarding.
      final cachedName = _shopService.cachedShopName;
      final cachedCode = _shopService.cachedShopCode;
      if (cachedName != null || cachedCode != null) {
        _emit(AccountState(
          stage: AccountStage.businessPending,
          shopId: shopId,
          shopName: cachedName,
          shopCode: cachedCode,
          role: AccountRole.owner,
        ));
      } else {
        _emit(AccountState.noAccount);
      }
      return;
    }

    final shopStatus =
        (shop[AccountApproval.fieldStatus] as String?) ??
            AccountApproval.statusApproved;
    final shopName = shop['name'] as String?;
    final shopCode = shop['code'] as String?;

    if (shopStatus == AccountApproval.statusRejected) {
      _emit(AccountState(
        stage: AccountStage.businessRejected,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: AccountRole.owner,
        displayName: shop['ownerName'] as String?,
        phone: shop['ownerPhone'] as String? ?? shop['businessPhone'] as String?,
        rejectionReason: shop[AccountApproval.fieldRejectionReason] as String?,
      ));
      return;
    }

    if (shopStatus == AccountApproval.statusPendingSystemAdmin) {
      _emit(AccountState(
        stage: AccountStage.businessPending,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: AccountRole.owner,
        displayName: shop['ownerName'] as String?,
        phone: shop['ownerPhone'] as String? ?? shop['businessPhone'] as String?,
      ));
      return;
    }

    // Shop is approved (or legacy doc with no status). Now look at the
    // current device's member status.
    final member = _lastMember;
    if (member == null) {
      _emit(AccountState(
        stage: AccountStage.staffPending,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: AccountRole.staff,
      ));
      return;
    }

    final memberStatus =
        (member[AccountApproval.fieldStatus] as String?) ??
            AccountApproval.statusApproved;
    final roleStr =
        (member['role'] as String?) ?? AccountApproval.roleStaff;
    final role = roleStr == AccountApproval.roleOwner
        ? AccountRole.owner
        : AccountRole.staff;
    final displayName = member['displayName'] as String?;
    final phone = member['phone'] as String?;

    if (memberStatus == AccountApproval.statusRejected) {
      _emit(AccountState(
        stage: AccountStage.staffRejected,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: role,
        displayName: displayName,
        phone: phone,
        rejectionReason:
            member[AccountApproval.fieldRejectionReason] as String?,
      ));
      return;
    }

    if (memberStatus == AccountApproval.statusPendingOwner) {
      _emit(AccountState(
        stage: AccountStage.staffPending,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: role,
        displayName: displayName,
        phone: phone,
      ));
      return;
    }

    _emit(AccountState(
      stage: AccountStage.approved,
      shopId: shopId,
      shopName: shopName,
      shopCode: shopCode,
      role: role,
      displayName: displayName,
      phone: phone,
    ));
  }

  void _emit(AccountState state) {
    _current = state;
    final c = _controller;
    if (c != null && !c.isClosed) {
      c.add(state);
    }
  }

  // ---------- public API ----------

  /// Owner submits a new business registration. Creates
  /// `/shops/{newId}` with `approvalStatus: pendingSystemAdmin` and
  /// adds the current device's user as the approved owner member.
  Future<AccountActionResult> submitBusinessRegistration({
    required String businessName,
    required String ownerName,
    required String phoneNumber,
  }) async {
    final name = businessName.trim();
    final owner = ownerName.trim();
    final phone = phoneNumber.trim();
    if (name.isEmpty) {
      return AccountActionResult.fail('Business name is required.');
    }
    if (owner.isEmpty) {
      return AccountActionResult.fail('Your name is required.');
    }
    if (phone.isEmpty) {
      return AccountActionResult.fail('Phone number is required.');
    }
    if (!FirebaseInit.available) {
      return AccountActionResult.fail(
        'Cloud is not configured on this device. Account approval '
        'requires Firebase.',
      );
    }
    final auth = await _shopService.ensureAuthDetailed();
    final uid = auth.uid;
    if (uid == null) {
      return AccountActionResult.fail('Sign-in failed: ${auth.describe()}');
    }

    try {
      final db = FirebaseFirestore.instance;
      final existingOwned = await db
          .collection(FirestorePaths.shopsCollection)
          .where('ownerUid', isEqualTo: uid)
          .limit(5)
          .get();
      for (final doc in existingOwned.docs) {
        final data = doc.data();
        final status =
            (data[AccountApproval.fieldStatus] as String?) ??
                AccountApproval.statusApproved;
        if (status == AccountApproval.statusRejected) {
          continue;
        }
        final existingCode = (data['code'] as String?) ?? '';
        final existingName = (data['name'] as String?) ?? name;
        await _shopService.persistShopCache(
          id: doc.id,
          code: existingCode,
          name: existingName,
        );
        await refresh();
        return AccountActionResult.ok(
          status == AccountApproval.statusApproved
              ? 'This device is already linked to $existingName '
                  '(code $existingCode).'
              : 'You already submitted $existingName '
                  '(code $existingCode). Waiting for approval.',
        );
      }

      final code = await _generateShopCode(db);
      final shopRef =
          db.collection(FirestorePaths.shopsCollection).doc();
      final nowIso = DateTime.now().toIso8601String();

      try {
        await shopRef.set({
          'code': code,
          'name': name,
          'ownerUid': uid,
          'ownerName': owner,
          'ownerPhone': phone,
          'businessPhone': phone,
          'createdAt': nowIso,
          'memberCount': 1,
          AccountApproval.fieldStatus:
              AccountApproval.statusPendingSystemAdmin,
          AccountApproval.fieldRequestedAt: nowIso,
        });
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          return AccountActionResult.fail(
            'Could not save the business request. Deploy Firestore rules '
            'from this repo (`npx -y firebase-tools@latest deploy '
            '--only firestore:rules`) and try again.',
          );
        }
        rethrow;
      }
      try {
        await shopRef
            .collection(FirestorePaths.membersSubcollection)
            .doc(uid)
            .set({
          'uid': uid,
          'role': AccountApproval.roleOwner,
          'displayName': owner,
          'phone': phone,
          'joinedAt': nowIso,
          AccountApproval.fieldStatus: AccountApproval.statusApproved,
          AccountApproval.fieldApprovedAt: nowIso,
        });
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          return AccountActionResult.fail(
            'Could not save owner profile for this business. Deploy '
            'Firestore rules from this repo and try again.',
          );
        }
        rethrow;
      }

      await _shopService.persistShopCache(
        id: shopRef.id,
        code: code,
        name: name,
      );
      unawaited(refresh());
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      return AccountActionResult.ok(
        'Business request submitted. Waiting for system admin approval.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('submitBusinessRegistration error: $e');
      }
      return AccountActionResult.fail('Failed to submit request: $e');
    }
  }

  /// Staff submits a join request to an approved business.
  Future<AccountActionResult> submitStaffJoinRequest({
    required String shopId,
    required String displayName,
    String? phoneNumber,
  }) async {
    final name = displayName.trim();
    if (shopId.isEmpty) {
      return AccountActionResult.fail('Select a business first.');
    }
    if (name.isEmpty) {
      return AccountActionResult.fail('Your name is required.');
    }
    if (!FirebaseInit.available) {
      return AccountActionResult.fail(
        'Cloud is not configured on this device.',
      );
    }
    final auth = await _shopService.ensureAuthDetailed();
    final uid = auth.uid;
    if (uid == null) {
      return AccountActionResult.fail('Sign-in failed: ${auth.describe()}');
    }

    try {
      final db = FirebaseFirestore.instance;
      final shopRef =
          db.collection(FirestorePaths.shopsCollection).doc(shopId);
      final shopSnap = await shopRef.get();
      if (!shopSnap.exists) {
        return AccountActionResult.fail('Business not found.');
      }
      final shopData = shopSnap.data() as Map<String, dynamic>;
      final shopStatus =
          (shopData[AccountApproval.fieldStatus] as String?) ??
              AccountApproval.statusApproved;
      if (shopStatus != AccountApproval.statusApproved) {
        return AccountActionResult.fail(
          'This business is not yet approved by the system admin.',
        );
      }

      final nowIso = DateTime.now().toIso8601String();
      await shopRef
          .collection(FirestorePaths.membersSubcollection)
          .doc(uid)
          .set({
        'uid': uid,
        'role': AccountApproval.roleStaff,
        'displayName': name,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone': phoneNumber.trim(),
        'joinedAt': nowIso,
        AccountApproval.fieldStatus: AccountApproval.statusPendingOwner,
        AccountApproval.fieldRequestedAt: nowIso,
      }, SetOptions(merge: true));

      await _shopService.persistShopCache(
        id: shopId,
        code: (shopData['code'] as String?) ?? '',
        name: (shopData['name'] as String?) ?? 'Business',
      );
      unawaited(refresh());
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      return AccountActionResult.ok(
        'Request sent. Waiting for the business owner to approve.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('submitStaffJoinRequest error: $e');
      }
      return AccountActionResult.fail('Failed to submit request: $e');
    }
  }

  /// Searches the directory of approved businesses by name/code.
  /// Returns up to 25 best-matching results. Empty query → empty.
  Future<List<BusinessSummary>> searchApprovedBusinesses(
    String query,
  ) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    if (!FirebaseInit.available) return const [];
    final uid = await _shopService.ensureAuth();
    if (uid == null) return const [];

    try {
      final db = FirebaseFirestore.instance;
      final snap = await db
          .collection(FirestorePaths.shopsCollection)
          .where(
            AccountApproval.fieldStatus,
            isEqualTo: AccountApproval.statusApproved,
          )
          .limit(200)
          .get();

      final out = <BusinessSummary>[];
      for (final d in snap.docs) {
        final data = d.data();
        final name = ((data['name'] as String?) ?? '').trim();
        final code = ((data['code'] as String?) ?? '').trim();
        if (name.isEmpty) continue;
        final hayName = name.toLowerCase();
        final hayCode = code.toLowerCase();
        if (!hayName.contains(q) && hayCode != q) {
          continue;
        }
        out.add(BusinessSummary(
          id: d.id,
          name: name,
          code: code,
          ownerName: data['ownerName'] as String?,
        ));
      }
      out.sort((a, b) {
        final aStarts = a.name.toLowerCase().startsWith(q);
        final bStarts = b.name.toLowerCase().startsWith(q);
        if (aStarts != bStarts) {
          return aStarts ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return out.take(25).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('searchApprovedBusinesses error: $e');
      }
      return const [];
    }
  }

  /// Approves a pending staff member. Caller must already be the
  /// approved owner of the shop (enforced by security rules).
  Future<AccountActionResult> ownerApproveMember({
    required String shopId,
    required String memberUid,
  }) async {
    return _ownerWriteMember(
      shopId: shopId,
      memberUid: memberUid,
      payload: {
        AccountApproval.fieldStatus: AccountApproval.statusApproved,
        AccountApproval.fieldApprovedAt: DateTime.now().toIso8601String(),
        AccountApproval.fieldRejectedAt: FieldValue.delete(),
        AccountApproval.fieldRejectionReason: FieldValue.delete(),
      },
      okMessage: 'Staff member approved.',
    );
  }

  /// Rejects a pending staff member with an optional reason.
  Future<AccountActionResult> ownerRejectMember({
    required String shopId,
    required String memberUid,
    String? reason,
  }) async {
    final trimmed = (reason ?? '').trim();
    return _ownerWriteMember(
      shopId: shopId,
      memberUid: memberUid,
      payload: {
        AccountApproval.fieldStatus: AccountApproval.statusRejected,
        AccountApproval.fieldRejectedAt: DateTime.now().toIso8601String(),
        if (trimmed.isNotEmpty)
          AccountApproval.fieldRejectionReason: trimmed,
      },
      okMessage: 'Staff request rejected.',
    );
  }

  /// Removes a staff member entirely.
  Future<AccountActionResult> ownerRemoveMember({
    required String shopId,
    required String memberUid,
  }) async {
    if (!FirebaseInit.available) {
      return AccountActionResult.fail('Cloud is not configured.');
    }
    final uid = await _shopService.ensureAuth();
    if (uid == null) {
      return AccountActionResult.fail('Sign-in failed.');
    }
    if (uid == memberUid) {
      return AccountActionResult.fail(
        'Owners cannot remove themselves. Use Start over instead.',
      );
    }
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection(FirestorePaths.membersSubcollection)
          .doc(memberUid)
          .delete();
      return AccountActionResult.ok('Staff member removed.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ownerRemoveMember error: $e');
      }
      return AccountActionResult.fail('Failed to remove member: $e');
    }
  }

  Future<AccountActionResult> _ownerWriteMember({
    required String shopId,
    required String memberUid,
    required Map<String, dynamic> payload,
    required String okMessage,
  }) async {
    if (!FirebaseInit.available) {
      return AccountActionResult.fail('Cloud is not configured.');
    }
    final uid = await _shopService.ensureAuth();
    if (uid == null) {
      return AccountActionResult.fail('Sign-in failed.');
    }
    try {
      final merged = {
        ...payload,
        AccountApproval.fieldApprovedBy: uid,
      };
      await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection(FirestorePaths.membersSubcollection)
          .doc(memberUid)
          .set(merged, SetOptions(merge: true));
      return AccountActionResult.ok(okMessage);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('_ownerWriteMember error: $e');
      }
      return AccountActionResult.fail('Failed: $e');
    }
  }

  /// Clears the device's current shop binding so the user can submit a
  /// fresh request after a rejection. Best-effort: also removes the
  /// owner's pending/rejected shop doc (rules permit owners to delete
  /// their own non-approved shop).
  Future<AccountActionResult> startOver() async {
    try {
      if (FirebaseInit.available) {
        final uid = await _shopService.ensureAuth();
        final shopId = _shopService.cachedShopId;
        if (uid != null && shopId != null && shopId.isNotEmpty) {
          final db = FirebaseFirestore.instance;
          final shopRef =
              db.collection(FirestorePaths.shopsCollection).doc(shopId);
          final snap = await shopRef.get();
          final data = snap.data() ?? <String, dynamic>{};
          final ownerUid = data['ownerUid'] as String?;
          final status =
              (data[AccountApproval.fieldStatus] as String?) ??
                  AccountApproval.statusApproved;

          // Owner of a non-approved shop: delete shop + own member doc.
          if (ownerUid == uid &&
              status != AccountApproval.statusApproved) {
            try {
              await shopRef
                  .collection(FirestorePaths.membersSubcollection)
                  .doc(uid)
                  .delete();
            } catch (_) {/* best-effort */}
            try {
              await shopRef.delete();
            } catch (_) {/* best-effort */}
          } else {
            // Staff or owner of an approved shop: just remove our own
            // member doc so we can re-request later.
            try {
              await shopRef
                  .collection(FirestorePaths.membersSubcollection)
                  .doc(uid)
                  .delete();
            } catch (_) {/* best-effort */}
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('startOver error: $e');
      }
    }
    await _shopService.leaveShop();
    await refresh();
    return AccountActionResult.ok('You can submit a new request now.');
  }

  Future<String> _generateShopCode(FirebaseFirestore db) async {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    const length = 6;
    final random = Random.secure();
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = List.generate(
        length,
        (_) => alphabet[random.nextInt(alphabet.length)],
      ).join();
      final existing = await db
          .collection(FirestorePaths.shopsCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    return List.generate(
      length + 2,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
