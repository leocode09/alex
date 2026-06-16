import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/account_state.dart';
import '../admin/device_heartbeat_service.dart';
import '../admin/license_service.dart';
import 'firebase_init.dart';
import 'firestore_paths.dart';
import 'shop_service.dart';
import 'staff_join_request_writer.dart';
import 'user_auth_service.dart';

/// Drives the phone + password account / business-approval workflow.
///
/// Identity is a stable Firebase uid keyed by phone (see
/// [UserAuthService]), so this service is a straightforward reducer:
///
///   - watches `/shops/{shopId}` and `/shops/{shopId}/members/{uid}` and
///     reduces them into an [AccountState];
///   - on (re)attach, claims any shop whose `ownerPhoneKey` matches the
///     logged-in user (migration / new-device recovery) by re-binding
///     `ownerUid`;
///   - lets a business owner register a new business
///     (`approvalStatus: pendingSystemAdmin`);
///   - lets a staff member submit a join request (`pendingOwner`);
///   - lets an approved owner approve / reject / remove staff.
///
/// All writes degrade gracefully when Firebase is unavailable.
class AccountService {
  AccountService._internal();
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;

  final ShopService _shopService = ShopService();
  final UserAuthService _userAuth = UserAuthService();

  StreamController<AccountState>? _controller;
  AccountState _current = AccountState.unknown;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _shopSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;
  StreamSubscription<User?>? _authSub;

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
    // React to login / logout so the gate updates immediately.
    if (FirebaseInit.available) {
      _authSub ??= _userAuth.authStateChanges().listen((_) {
        unawaited(_reattach());
      });
    }
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

      final uid = _userAuth.currentUid;
      if (uid == null) {
        await _detach();
        _emit(AccountState.signedOut);
        return;
      }

      // Migration / new-device recovery: re-bind any shop this phone
      // owns to the current uid before resolving membership.
      await _claimOwnedShops(uid);

      await _shopService.loadCache();
      var shopId = _shopService.cachedShopId;
      if (shopId == null || shopId.isEmpty) {
        shopId = await _resolveShopIdForUser(uid);
        if (shopId != null && shopId.isNotEmpty) {
          await _cacheShopFromDoc(shopId);
        }
      }

      if (shopId == null || shopId.isEmpty) {
        await _detach();
        _emit(AccountState.noAccount.copyWithUid(uid));
        return;
      }

      if (_attachedShopId != shopId || _attachedUid != uid) {
        await _detach();
        _attachedShopId = shopId;
        _attachedUid = uid;
        _shopSub = FirebaseFirestore.instance
            .collection(FirestorePaths.shopsCollection)
            .doc(shopId)
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
            .doc(shopId)
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

      await _fetchLatestDocs(shopId, uid);
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

  /// Finds the shop this user belongs to without relying on local cache:
  /// first a shop they own, then the pointer stored on `/users/{uid}`.
  Future<String?> _resolveShopIdForUser(String uid) async {
    try {
      final owned = await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (owned.docs.isNotEmpty) {
        return owned.docs.first.id;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._resolveShopIdForUser owned error: $e');
      }
    }
    return _userAuth.storedShopId();
  }

  Future<void> _cacheShopFromDoc(String shopId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .get();
      final data = snap.data() ?? <String, dynamic>{};
      await _shopService.persistShopCache(
        id: shopId,
        code: (data['code'] as String?) ?? '',
        name: (data['name'] as String?) ?? 'Business',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._cacheShopFromDoc error: $e');
      }
    }
  }

  /// Re-binds any shop whose `ownerPhoneKey` matches this user's phone to
  /// the current uid, and ensures an approved owner member doc exists.
  /// This is the migration path (old anonymous-uid owners) and the
  /// new-device recovery path. Best-effort and never throws.
  Future<void> _claimOwnedShops(String uid) async {
    try {
      final phone = await _userAuth.currentPhone();
      if (phone == null || phone.trim().isEmpty) return;
      final phoneKey = _userAuth.normalizePhone(phone);
      if (phoneKey.length < 9) return;

      final matches = await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .where('ownerPhoneKey', isEqualTo: phoneKey)
          .limit(5)
          .get();
      if (matches.docs.isEmpty) return;

      for (final doc in matches.docs) {
        final data = doc.data();
        final currentOwner = data['ownerUid'] as String?;
        if (currentOwner == uid) {
          await _ensureOwnerMemberDoc(shopId: doc.id, shopData: data, uid: uid);
          continue;
        }
        try {
          await doc.reference.update({
            'ownerUid': uid,
            if ((data['ownerName'] as String?)?.trim().isNotEmpty != true)
              'ownerName': 'Owner',
          });
          await _ensureOwnerMemberDoc(
            shopId: doc.id,
            shopData: {...data, 'ownerUid': uid},
            uid: uid,
          );
        } on FirebaseException catch (e) {
          if (kDebugMode) {
            debugPrint('AccountService claim update denied: ${e.code}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._claimOwnedShops error: $e');
      }
    }
  }

  Future<void> _ensureOwnerMemberDoc({
    required String shopId,
    required Map<String, dynamic> shopData,
    required String uid,
  }) async {
    try {
      final memberRef = FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection(FirestorePaths.membersSubcollection)
          .doc(uid);
      final memberSnap = await memberRef.get();
      final memberData = memberSnap.data();
      final isOwnerApproved = memberSnap.exists &&
          memberData?['role'] == AccountApproval.roleOwner &&
          ((memberData?[AccountApproval.fieldStatus] as String?) ??
                  AccountApproval.statusApproved) ==
              AccountApproval.statusApproved;
      if (isOwnerApproved) return;

      final nowIso = DateTime.now().toIso8601String();
      final ownerName =
          ((shopData['ownerName'] as String?)?.trim().isNotEmpty ?? false)
              ? (shopData['ownerName'] as String).trim()
              : 'Owner';
      final ownerPhone = (shopData['ownerPhone'] as String?) ??
          await _userAuth.currentPhone();
      await memberRef.set({
        'uid': uid,
        'role': AccountApproval.roleOwner,
        'displayName': ownerName,
        if (ownerPhone != null && ownerPhone.trim().isNotEmpty)
          'phone': ownerPhone.trim(),
        'joinedAt': nowIso,
        AccountApproval.fieldStatus: AccountApproval.statusApproved,
        AccountApproval.fieldApprovedAt: nowIso,
      }, SetOptions(merge: true));
      await _userAuth.setShopMembership(
        shopId: shopId,
        role: AccountApproval.roleOwner,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._ensureOwnerMemberDoc error: $e');
      }
    }
  }

  void _emitMerged() {
    final uid = _attachedUid;
    final shopId = _attachedShopId;
    if (uid == null || shopId == null || shopId.isEmpty) {
      _emit(AccountState.noAccount.copyWithUid(uid));
      return;
    }

    final shop = _lastShop;
    if (shop == null) {
      // Shop doc still loading / temporarily unreadable. Stay on the
      // current gate using the cached identity instead of bouncing back
      // to onboarding.
      final cachedName = _shopService.cachedShopName;
      final cachedCode = _shopService.cachedShopCode;
      if (cachedName != null || cachedCode != null) {
        _emit(AccountState(
          stage: AccountStage.unknown,
          uid: uid,
          shopId: shopId,
          shopName: cachedName,
          shopCode: cachedCode,
        ));
      } else {
        _emit(AccountState.noAccount.copyWithUid(uid));
      }
      return;
    }

    final shopStatus = (shop[AccountApproval.fieldStatus] as String?) ??
        AccountApproval.statusApproved;
    final shopName = shop['name'] as String?;
    final shopCode = shop['code'] as String?;
    final ownerUid = shop['ownerUid'] as String?;
    final isOwnerOfShop = ownerUid == uid;

    if (shopStatus == AccountApproval.statusRejected) {
      _emit(AccountState(
        stage: AccountStage.businessRejected,
        uid: uid,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: AccountRole.owner,
        displayName: shop['ownerName'] as String?,
        phone: shop['ownerPhone'] as String?,
        rejectionReason: shop[AccountApproval.fieldRejectionReason] as String?,
      ));
      return;
    }

    if (shopStatus == AccountApproval.statusPendingSystemAdmin) {
      _emit(AccountState(
        stage: AccountStage.businessPending,
        uid: uid,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: AccountRole.owner,
        displayName: shop['ownerName'] as String?,
        phone: shop['ownerPhone'] as String?,
      ));
      return;
    }

    // Shop approved (or legacy doc). Resolve this device's member status.
    final member = _lastMember;
    if (member == null) {
      // The shop owner whose member doc is missing is repaired by the
      // claim path; surface a staff-pending gate for everyone else.
      _emit(AccountState(
        stage: AccountStage.staffPending,
        uid: uid,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: isOwnerOfShop ? AccountRole.owner : AccountRole.staff,
      ));
      return;
    }

    final memberStatus = (member[AccountApproval.fieldStatus] as String?) ??
        AccountApproval.statusApproved;
    final roleStr = (member['role'] as String?) ?? AccountApproval.roleStaff;
    final role = roleStr == AccountApproval.roleOwner
        ? AccountRole.owner
        : AccountRole.staff;
    final displayName = member['displayName'] as String?;
    final phone = member['phone'] as String?;

    if (memberStatus == AccountApproval.statusRejected) {
      _emit(AccountState(
        stage: AccountStage.staffRejected,
        uid: uid,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: role,
        displayName: displayName,
        phone: phone,
        rejectionReason: member[AccountApproval.fieldRejectionReason] as String?,
      ));
      return;
    }

    if (memberStatus == AccountApproval.statusPendingOwner) {
      _emit(AccountState(
        stage: AccountStage.staffPending,
        uid: uid,
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
      uid: uid,
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

  // ---------- auth API ----------

  /// Registers a new phone + password account, then refreshes state.
  Future<UserAuthResult> registerAccount({
    required String phone,
    required String password,
    required String displayName,
  }) async {
    final result = await _userAuth.register(
      phone: phone,
      password: password,
      displayName: displayName,
    );
    if (result.success) {
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      await refresh();
    }
    return result;
  }

  /// Logs in with phone + password, then refreshes state.
  Future<UserAuthResult> loginAccount({
    required String phone,
    required String password,
  }) async {
    final result = await _userAuth.login(phone: phone, password: password);
    if (result.success) {
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      await refresh();
    }
    return result;
  }

  // ---------- business / staff onboarding ----------

  /// Owner submits a new business registration using the logged-in
  /// identity. Creates `/shops/{newId}` (pendingSystemAdmin) plus the
  /// owner's approved member doc.
  Future<AccountActionResult> submitBusinessRegistration({
    required String businessName,
    required String ownerName,
    String? phoneNumber,
  }) async {
    final name = businessName.trim();
    final owner = ownerName.trim();
    if (name.isEmpty) {
      return AccountActionResult.fail('Business name is required.');
    }
    if (owner.isEmpty) {
      return AccountActionResult.fail('Your name is required.');
    }
    if (!FirebaseInit.available) {
      return AccountActionResult.fail(
        'Cloud is not configured on this device. Account approval '
        'requires Firebase.',
      );
    }
    final uid = _userAuth.currentUid;
    if (uid == null) {
      return AccountActionResult.fail('Please log in first.');
    }

    final accountPhone = await _userAuth.currentPhone();
    final phone = ((phoneNumber ?? '').trim().isNotEmpty)
        ? phoneNumber!.trim()
        : (accountPhone ?? '');
    if (phone.isEmpty) {
      return AccountActionResult.fail('Phone number is required.');
    }
    final phoneKey = _userAuth.normalizePhone(phone);

    try {
      final db = FirebaseFirestore.instance;
      final existingOwned = await db
          .collection(FirestorePaths.shopsCollection)
          .where('ownerUid', isEqualTo: uid)
          .limit(5)
          .get();
      for (final doc in existingOwned.docs) {
        final data = doc.data();
        final status = (data[AccountApproval.fieldStatus] as String?) ??
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
              ? 'You already own $existingName (code $existingCode).'
              : 'You already submitted $existingName '
                  '(code $existingCode). Waiting for approval.',
        );
      }

      final code = await _generateShopCode(db);
      final shopRef = db.collection(FirestorePaths.shopsCollection).doc();
      final nowIso = DateTime.now().toIso8601String();

      try {
        await shopRef.set({
          'code': code,
          'name': name,
          'ownerUid': uid,
          'ownerName': owner,
          'ownerPhone': phone,
          'businessPhone': phone,
          'ownerPhoneKey': phoneKey,
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
      await _userAuth.setShopMembership(
        shopId: shopRef.id,
        role: AccountApproval.roleOwner,
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
      return AccountActionResult.fail('Cloud is not configured on this device.');
    }
    final uid = _userAuth.currentUid;
    if (uid == null) {
      return AccountActionResult.fail('Please log in first.');
    }

    final accountPhone = await _userAuth.currentPhone();
    final phone = ((phoneNumber ?? '').trim().isNotEmpty)
        ? phoneNumber!.trim()
        : accountPhone;

    try {
      final db = FirebaseFirestore.instance;
      final shopRef = db.collection(FirestorePaths.shopsCollection).doc(shopId);
      final shopSnap = await shopRef.get();
      if (!shopSnap.exists) {
        return AccountActionResult.fail('Business not found.');
      }
      final shopData = shopSnap.data() as Map<String, dynamic>;
      final shopStatus = (shopData[AccountApproval.fieldStatus] as String?) ??
          AccountApproval.statusApproved;
      if (shopStatus != AccountApproval.statusApproved) {
        return AccountActionResult.fail(
          'This business is not yet approved by the system admin.',
        );
      }

      final shopName = (shopData['name'] as String?) ?? 'Business';
      final shopCode = (shopData['code'] as String?) ?? '';

      if (shopData['ownerUid'] == uid) {
        await _ensureOwnerMemberDoc(
          shopId: shopId,
          shopData: {
            ...shopData,
            'ownerName': name,
            if (phone != null && phone.trim().isNotEmpty) 'ownerPhone': phone,
          },
          uid: uid,
        );
        await _shopService.persistShopCache(
          id: shopId,
          code: shopCode,
          name: shopName,
        );
        unawaited(refresh());
        unawaited(DeviceHeartbeatService().refreshShopMembership());
        unawaited(LicenseService().refresh());
        return AccountActionResult.ok('Welcome back to $shopName.');
      }

      final memberRef =
          shopRef.collection(FirestorePaths.membersSubcollection).doc(uid);
      final writeResult = await StaffJoinRequestWriter.upsert(
        memberRef: memberRef,
        uid: uid,
        displayName: name,
        phoneNumber: phone,
      );
      if (!writeResult.success) {
        return AccountActionResult.fail(
          writeResult.errorMessage ?? 'Failed to submit request.',
        );
      }

      await _shopService.persistShopCache(
        id: shopId,
        code: shopCode,
        name: shopName,
      );
      await _userAuth.setShopMembership(
        shopId: shopId,
        role: AccountApproval.roleStaff,
      );
      unawaited(refresh());
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());

      if (writeResult.outcome == StaffJoinWriteOutcome.alreadyMember) {
        return AccountActionResult.ok('You are already a member of $shopName.');
      }
      return AccountActionResult.ok(
        'Request sent. Waiting for the business owner to approve.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return AccountActionResult.fail(
          'Could not send join request. Ask the shop owner to update '
          'Firestore rules, or contact support.',
        );
      }
      if (kDebugMode) {
        debugPrint('submitStaffJoinRequest FirebaseException: $e');
      }
      return AccountActionResult.fail('Failed to submit request: $e');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('submitStaffJoinRequest error: $e');
      }
      return AccountActionResult.fail('Failed to submit request: $e');
    }
  }

  /// Searches the directory of approved businesses by name/code.
  Future<List<BusinessSummary>> searchApprovedBusinesses(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    if (!FirebaseInit.available) return const [];
    if (_userAuth.currentUid == null) return const [];

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

  // ---------- owner staff management ----------

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
        if (trimmed.isNotEmpty) AccountApproval.fieldRejectionReason: trimmed,
      },
      okMessage: 'Staff request rejected.',
    );
  }

  Future<AccountActionResult> ownerRemoveMember({
    required String shopId,
    required String memberUid,
  }) async {
    if (!FirebaseInit.available) {
      return AccountActionResult.fail('Cloud is not configured.');
    }
    final uid = _userAuth.currentUid;
    if (uid == null) {
      return AccountActionResult.fail('Please log in first.');
    }
    if (uid == memberUid) {
      return AccountActionResult.fail(
        'Owners cannot remove themselves. Use Log out instead.',
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
    final uid = _userAuth.currentUid;
    if (uid == null) {
      return AccountActionResult.fail('Please log in first.');
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

  // ---------- session ----------

  /// Logs the user out completely (Firebase sign-out + local shop cache).
  Future<AccountActionResult> logoutAccount() async {
    try {
      await _detach();
      await _shopService.leaveShop();
      await _userAuth.signOut();
      _emit(AccountState.signedOut);
      return AccountActionResult.ok('Logged out.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('logoutAccount error: $e');
      }
      return AccountActionResult.fail('Failed to log out: $e');
    }
  }

  /// Clears this device's shop binding so a rejected user can submit a
  /// fresh request. The owner of a still-pending / rejected shop also
  /// deletes that shop doc. Keeps the user logged in.
  Future<AccountActionResult> startOver() async {
    try {
      if (FirebaseInit.available) {
        final uid = _userAuth.currentUid;
        final shopId = _shopService.cachedShopId ?? _attachedShopId;
        if (uid != null && shopId != null && shopId.isNotEmpty) {
          final db = FirebaseFirestore.instance;
          final shopRef =
              db.collection(FirestorePaths.shopsCollection).doc(shopId);
          final snap = await shopRef.get();
          final data = snap.data() ?? <String, dynamic>{};
          final ownerUid = data['ownerUid'] as String?;
          final status = (data[AccountApproval.fieldStatus] as String?) ??
              AccountApproval.statusApproved;

          if (ownerUid == uid && status != AccountApproval.statusApproved) {
            try {
              await shopRef
                  .collection(FirestorePaths.membersSubcollection)
                  .doc(uid)
                  .delete();
            } catch (_) {/* best-effort */}
            try {
              await shopRef.delete();
            } catch (_) {/* best-effort */}
          } else if (ownerUid != uid) {
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
    await _userAuth.setShopMembership(shopId: '', role: '');
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
