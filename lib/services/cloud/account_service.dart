import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/account_state.dart';
import '../admin/device_heartbeat_service.dart';
import '../admin/device_registration_service.dart';
import '../admin/license_service.dart';
import '../identity_label.dart';
import 'auth_support.dart';
import 'business_search.dart';
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<User?>? _authSub;

  String? _attachedShopId;
  String? _attachedUid;
  Map<String, dynamic>? _lastShop;
  Map<String, dynamic>? _lastMember;
  Map<String, dynamic>? _lastUser;
  Future<void> _attachTail = Future.value();

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
    // The auth listener is attached inside [_performAttach] once Firebase
    // init (which now runs in the background at boot) has completed, so
    // a kickstart that races app boot doesn't misread "unavailable".
    unawaited(_enqueueAttach());
  }

  /// Call after the user creates / joins / leaves a shop so the
  /// listeners reattach to the new shop id.
  Future<void> refresh() => _enqueueAttach();

  /// Waits until every attach already queued has finished. Does not
  /// start a new attach by itself — used by LAN start so a cold boot
  /// does not read [current] while it is still [AccountStage.unknown].
  Future<void> waitForAttachIfInFlight() async {
    Future<void> current;
    do {
      current = _attachTail;
      await current;
    } while (!identical(current, _attachTail));
  }

  Future<void> _enqueueAttach() {
    final run = _attachTail.then((_) => _performAttach());
    _attachTail = run.onError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('AccountService attach error: $e\n$st');
      }
    });
    return run;
  }

  Future<void> _performAttach() async {
    // Firebase init runs in the background at boot; wait for it to
    // settle (a fast no-op once completed) so we only report
    // "firebase down" when init actually failed, not merely because
    // it has not finished yet. This does not block the first frame —
    // the router reads [current] synchronously.
    await FirebaseInit.ensureInitialized();
    if (!FirebaseInit.available) {
      await _shopService.loadCache();
      final cachedId = _shopService.cachedShopId?.trim();
      _emit(AccountState(
        stage: AccountStage.unknown,
        firebaseUnavailable: true,
        shopId: (cachedId != null && cachedId.isNotEmpty) ? cachedId : null,
        shopName: _shopService.cachedShopName,
        shopCode: _shopService.cachedShopCode,
      ));
      return;
    }

    try {
      // React to login / logout so the gate updates immediately.
      _authSub ??= _userAuth.authStateChanges().listen((_) {
        unawaited(_enqueueAttach());
      });

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
      // Prefer cloud membership (user pointer / owned shops) over a stale
      // local cache so support reassignment and multi-shop members land on
      // the correct business after login.
      var shopId = await _resolveShopIdForUser(uid);
      if (shopId == null || shopId.isEmpty) {
        shopId = _shopService.cachedShopId;
      }
      if (shopId != null &&
          shopId.isNotEmpty &&
          shopId != _shopService.cachedShopId) {
        await _cacheShopFromDoc(shopId);
      }

      if (shopId == null || shopId.isEmpty) {
        await _detach();
        final profile = await _userAuth.currentProfile();
        _lastUser = profile;
        _emit(AccountState(
          stage: AccountStage.noAccount,
          uid: uid,
          displayName: profile?['displayName'] as String?,
          phone: profile?['phone'] as String?,
        ));
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
        _userSub = FirebaseFirestore.instance
            .collection(FirestorePaths.usersCollection)
            .doc(uid)
            .snapshots()
            .listen(
          (doc) {
            _lastUser = doc.exists ? doc.data() : null;
            _emitMerged();
          },
          onError: (e) {
            if (kDebugMode) {
              debugPrint('AccountService user listener error: $e');
            }
          },
        );
      }

      await _fetchLatestDocs(shopId, uid);
      _emitMerged();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AccountService._performAttach error: $e\n$st');
      }
    }
  }

  Future<void> _detach() async {
    await _shopSub?.cancel();
    _shopSub = null;
    await _memberSub?.cancel();
    _memberSub = null;
    await _userSub?.cancel();
    _userSub = null;
    _attachedShopId = null;
    _attachedUid = null;
    _lastShop = null;
    _lastMember = null;
    _lastUser = null;
  }

  Future<void> _fetchLatestDocs(String shopId, String uid) async {
    final db = FirebaseFirestore.instance;
    await Future.wait([
      _readDocInto(
        db.collection(FirestorePaths.shopsCollection).doc(shopId).get(),
        (data) => _lastShop = data,
        'shop',
      ),
      _readDocInto(
        db
            .collection(FirestorePaths.shopsCollection)
            .doc(shopId)
            .collection(FirestorePaths.membersSubcollection)
            .doc(uid)
            .get(),
        (data) => _lastMember = data,
        'member',
      ),
      _readDocInto(
        db.collection(FirestorePaths.usersCollection).doc(uid).get(),
        (data) => _lastUser = data,
        'user',
      ),
    ]);
  }

  Future<void> _readDocInto(
    Future<DocumentSnapshot<Map<String, dynamic>>> future,
    void Function(Map<String, dynamic>? data) assign,
    String label,
  ) async {
    try {
      final snap = await future;
      assign(snap.exists ? snap.data() : null);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._fetchLatestDocs $label error: $e');
      }
      // Keep the previous snapshot so a single failed read cannot demote
      // an approved member to pending / unknown.
    }
  }

  /// Finds the shop this user belongs to without relying on local cache:
  /// first the pointer on `/users/{uid}`, then a shop they own, then an
  /// approved membership (cached shop or collection-group lookup).
  Future<String?> _resolveShopIdForUser(String uid) async {
    final stored = await _userAuth.storedShopId();
    if (stored != null && stored.isNotEmpty) {
      final look = await _memberLook(shopId: stored, uid: uid);
      // Keep the pointer whenever this uid still has a member doc there
      // (approved, pending, or rejected) or the read failed (offline).
      // Only search further when the pointer is proven stale.
      if (look != _MemberLook.missing) {
        return stored;
      }
    }

    try {
      final owned = await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .where('ownerUid', isEqualTo: uid)
          .limit(5)
          .get();
      if (owned.docs.isNotEmpty) {
        // A returning owner (cache cleared / reinstall) can own more than
        // one shop doc — e.g. a rejected attempt plus a live one. Prefer
        // the most useful: approved first, then one still awaiting review,
        // and only fall back to a rejected doc when nothing better exists.
        // A blind `.limit(1)` could otherwise bind them to a stale or
        // rejected shop and leave the app stuck "pending" against the
        // wrong document — exactly the state an admin approval can't fix.
        int rank(Map<String, dynamic> data) {
          final status = (data[AccountApproval.fieldStatus] as String?) ??
              AccountApproval.statusApproved;
          switch (status) {
            case AccountApproval.statusApproved:
              return 0;
            case AccountApproval.statusPendingSystemAdmin:
              return 1;
            case AccountApproval.statusRejected:
              return 3;
            default:
              return 2;
          }
        }

        final docs = [...owned.docs]
          ..sort((a, b) => rank(a.data()).compareTo(rank(b.data())));
        return docs.first.id;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._resolveShopIdForUser owned error: $e');
      }
    }

    final cached = _shopService.cachedShopId?.trim();
    if (cached != null &&
        cached.isNotEmpty &&
        cached != stored &&
        await _isApprovedMemberOf(shopId: cached, uid: uid)) {
      return cached;
    }

    final fromMembership = await _findShopIdFromMembership(uid);
    if (fromMembership != null && fromMembership.isNotEmpty) {
      return fromMembership;
    }

    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return null;
  }

  Future<bool> _isApprovedMemberOf({
    required String shopId,
    required String uid,
  }) async {
    return await _memberLook(shopId: shopId, uid: uid) == _MemberLook.approved;
  }

  Future<_MemberLook> _memberLook({
    required String shopId,
    required String uid,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection(FirestorePaths.membersSubcollection)
          .doc(uid)
          .get();
      if (!snap.exists) return _MemberLook.missing;
      final status = (snap.data()?[AccountApproval.fieldStatus] as String?) ??
          AccountApproval.statusApproved;
      if (status == AccountApproval.statusRejected) {
        return _MemberLook.rejected;
      }
      if (status == AccountApproval.statusPendingOwner) {
        return _MemberLook.pending;
      }
      return _MemberLook.approved;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService._memberLook error: $e');
      }
      return _MemberLook.unknown;
    }
  }

  Future<String?> _findShopIdFromMembership(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup(FirestorePaths.membersSubcollection)
          .where('uid', isEqualTo: uid)
          .limit(5)
          .get();
      String? pendingId;
      for (final doc in snap.docs) {
        final status =
            (doc.data()[AccountApproval.fieldStatus] as String?) ??
                AccountApproval.statusApproved;
        if (status == AccountApproval.statusRejected) continue;
        final shopId = doc.reference.parent.parent?.id;
        if (shopId == null || shopId.isEmpty) continue;
        if (status == AccountApproval.statusApproved) return shopId;
        pendingId ??= shopId;
      }
      return pendingId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'AccountService._findShopIdFromMembership error: $e',
        );
      }
      return null;
    }
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
      final profileName = await _userAuth.currentDisplayName();

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
              'ownerName': profileName ?? 'Owner',
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

      final nowIso = DateTime.now().toIso8601String();
      final profileName = await _userAuth.currentDisplayName();
      final shopOwnerName = (shopData['ownerName'] as String?)?.trim();
      final ownerName = profileName ??
          (shopOwnerName != null && shopOwnerName.isNotEmpty
              ? shopOwnerName
              : 'Owner');
      final ownerPhone = (await _userAuth.currentPhone()) ??
          shopData['ownerPhone'] as String?;
      final existingName = (memberData?['displayName'] as String?)?.trim();
      final existingPhone = (memberData?['phone'] as String?)?.trim();
      if (isOwnerApproved &&
          existingName == ownerName &&
          (ownerPhone == null || existingPhone == ownerPhone.trim())) {
        return;
      }

      await memberRef.set({
        'uid': uid,
        'role': AccountApproval.roleOwner,
        'displayName': ownerName,
        if (ownerPhone != null && ownerPhone.trim().isNotEmpty)
          'phone': ownerPhone.trim(),
        if (!memberSnap.exists) 'joinedAt': nowIso,
        AccountApproval.fieldStatus: AccountApproval.statusApproved,
        if (!isOwnerApproved) AccountApproval.fieldApprovedAt: nowIso,
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

  String? _canonicalDisplayName([String? fallback]) {
    final profileName = (_lastUser?['displayName'] as String?)?.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }
    final value = fallback?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _canonicalPhone([String? fallback]) {
    final profilePhone = (_lastUser?['phone'] as String?)?.trim();
    if (profilePhone != null && profilePhone.isNotEmpty) {
      return profilePhone;
    }
    final value = fallback?.trim();
    return value == null || value.isEmpty ? null : value;
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
      // Shop doc still loading / temporarily unreadable. Keep a known
      // approved gate for this shop so LAN / routing do not flap to
      // "not approved" while snapshots catch up.
      if (_isSameApprovedMembership(uid: uid, shopId: shopId)) {
        return;
      }
      final cachedName = _shopService.cachedShopName;
      final cachedCode = _shopService.cachedShopCode;
      if (cachedName != null || cachedCode != null) {
        _emit(AccountState(
          stage: AccountStage.unknown,
          uid: uid,
          shopId: shopId,
          shopName: cachedName,
          shopCode: cachedCode,
          displayName: _canonicalDisplayName(),
          phone: _canonicalPhone(),
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
        displayName:
            _canonicalDisplayName(shop['ownerName'] as String?),
        phone: _canonicalPhone(shop['ownerPhone'] as String?),
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
        displayName:
            _canonicalDisplayName(shop['ownerName'] as String?),
        phone: _canonicalPhone(shop['ownerPhone'] as String?),
      ));
      return;
    }

    // Shop approved (or legacy doc). Resolve this device's member status.
    final member = _lastMember;

    // The shop's owner is approved by definition once the shop itself is
    // approved. Never strand them on a staff-pending gate just because
    // their owner member doc is missing or stale (a failed write at
    // registration, or a legacy shop). That is a dead end the live shop
    // listener cannot recover from on its own, and a missing/unapproved
    // owner doc also blocks them from approving their own staff (the
    // security rules require an approved owner member doc). Repair the
    // doc in the background and let the owner straight in.
    if (isOwnerOfShop) {
      final hasApprovedOwnerDoc = member != null &&
          (member['role'] as String?) == AccountApproval.roleOwner &&
          ((member[AccountApproval.fieldStatus] as String?) ??
                  AccountApproval.statusApproved) ==
              AccountApproval.statusApproved;
      if (!hasApprovedOwnerDoc) {
        unawaited(
          _ensureOwnerMemberDoc(shopId: shopId, shopData: shop, uid: uid),
        );
      }
      _emit(AccountState(
        stage: AccountStage.approved,
        uid: uid,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: AccountRole.owner,
        displayName: _canonicalDisplayName(
          (member?['displayName'] as String?) ??
              shop['ownerName'] as String?,
        ),
        phone: _canonicalPhone(
          (member?['phone'] as String?) ?? shop['ownerPhone'] as String?,
        ),
      ));
      return;
    }

    if (member == null) {
      // A non-owner with no member doc has not been added to this shop
      // yet — surface the staff-pending gate. Do not demote a member we
      // already know is approved; a missing snapshot after reattach is
      // a fetch race, not a revocation.
      if (_isSameApprovedMembership(uid: uid, shopId: shopId)) {
        return;
      }
      _emit(AccountState(
        stage: AccountStage.staffPending,
        uid: uid,
        shopId: shopId,
        shopName: shopName,
        shopCode: shopCode,
        role: AccountRole.staff,
        displayName: _canonicalDisplayName(),
        phone: _canonicalPhone(),
      ));
      return;
    }

    final memberStatus = (member[AccountApproval.fieldStatus] as String?) ??
        AccountApproval.statusApproved;
    final roleStr = (member['role'] as String?) ?? AccountApproval.roleStaff;
    final role = roleStr == AccountApproval.roleOwner
        ? AccountRole.owner
        : AccountRole.staff;
    final displayName =
        _canonicalDisplayName(member['displayName'] as String?);
    final phone = _canonicalPhone(member['phone'] as String?);

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
    unawaited(IdentityLabel.updateFromAccount(state));
    final c = _controller;
    if (c != null && !c.isClosed) {
      c.add(state);
    }
  }

  bool _isSameApprovedMembership({
    required String uid,
    required String shopId,
  }) {
    return _current.stage == AccountStage.approved &&
        _current.uid == uid &&
        _current.shopId == shopId;
  }

  // ---------- auth API ----------

  /// Registers a new phone + password account, then refreshes state.
  Future<AuthAttemptResult> registerAccount({
    required String phone,
    required String password,
    required String displayName,
  }) async {
    // Fail closed before Auth create so a bound install cannot mint a
    // second Firebase user that would then need discarding.
    final precheck = await DeviceRegistrationService().assertCanRegister();
    if (precheck.status == DeviceBindingStatus.conflict) {
      return AuthAttemptResult.fail(precheck.message);
    }
    if (precheck.status == DeviceBindingStatus.unavailable &&
        FirebaseInit.available) {
      return AuthAttemptResult.fail(precheck.message);
    }

    final result = await _userAuth.register(
      phone: phone,
      password: password,
      displayName: displayName,
    );
    if (result.success) {
      final binding = await DeviceRegistrationService().bindToCurrentUser();
      if (!binding.isBound) {
        await _userAuth.discardJustRegisteredAccount();
        await _detach();
        _emit(AccountState.signedOut);
        return AuthAttemptResult.fail(
          binding.status == DeviceBindingStatus.conflict
              ? 'This device is already registered. Log in with the '
                  'original phone number, or ask an administrator to '
                  'unbind it.'
              : binding.message,
        );
      }
      await IdentityLabel.update(displayName);
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      await refresh();
    }
    return result;
  }

  /// Logs in with phone + password, then refreshes state.
  Future<AuthAttemptResult> loginAccount({
    required String phone,
    required String password,
  }) async {
    final result = await _userAuth.login(phone: phone, password: password);
    if (result.success) {
      final binding = await DeviceRegistrationService().bindToCurrentUser();
      if (!binding.isBound) {
        await _userAuth.signOut();
        await _detach();
        _emit(AccountState.signedOut);
        return AuthAttemptResult.fail(binding.message);
      }
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      unawaited(LicenseService().refresh());
      await refresh();
    }
    return result;
  }

  /// Changes the one person/device label and mirrors it to the active
  /// membership (and the shop owner label when applicable).
  Future<AccountActionResult> updateDisplayName(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      return AccountActionResult.fail('Your name is required.');
    }
    final uid = _userAuth.currentUid;
    if (uid == null) {
      return AccountActionResult.fail('Please log in first.');
    }
    if (!FirebaseInit.available) {
      await IdentityLabel.update(name);
      return AccountActionResult.ok('Name updated on this device.');
    }

    final profileUpdated = await _userAuth.updateDisplayName(name);
    if (!profileUpdated) {
      return AccountActionResult.fail('Could not update your name.');
    }
    try {
      final shopId = _current.shopId;
      if (shopId != null && shopId.isNotEmpty) {
        final db = FirebaseFirestore.instance;
        final batch = db.batch();
        final shopRef =
            db.collection(FirestorePaths.shopsCollection).doc(shopId);
        batch.set(
          shopRef
              .collection(FirestorePaths.membersSubcollection)
              .doc(uid),
          {'displayName': name},
          SetOptions(merge: true),
        );
        if (_current.isOwner) {
          batch.set(shopRef, {'ownerName': name}, SetOptions(merge: true));
        }
        await batch.commit();
      }
      _lastUser = <String, dynamic>{...?_lastUser, 'displayName': name};
      await IdentityLabel.update(name);
      await refresh();
      unawaited(DeviceHeartbeatService().refreshShopMembership());
      return AccountActionResult.ok('Your name is now $name.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AccountService.updateDisplayName error: $e');
      }
      return AccountActionResult.fail(
        'Your account name changed, but the shop profile could not be '
        'updated. Try again.',
      );
    }
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
    if (!await _userAuth.updateDisplayName(owner)) {
      return AccountActionResult.fail('Could not update your account name.');
    }
    _lastUser = <String, dynamic>{...?_lastUser, 'displayName': owner};

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
    if (!await _userAuth.updateDisplayName(name)) {
      return AccountActionResult.fail('Could not update your account name.');
    }
    _lastUser = <String, dynamic>{...?_lastUser, 'displayName': name};

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
  ///
  /// Loads the shop directory from the server (cache fallback when
  /// offline) and filters in memory. A failed directory read returns
  /// [BusinessSearchResult.fail] instead of an empty list so the UI can
  /// show the real reason instead of "no businesses match".
  Future<BusinessSearchResult> searchApprovedBusinesses(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return BusinessSearchResult.ok(const []);
    }

    await FirebaseInit.ensureInitialized();
    if (!FirebaseInit.available) {
      return BusinessSearchResult.fail(
        'Cloud is not available on this device, so businesses cannot be '
        'searched right now.',
      );
    }
    if (_userAuth.currentUid == null &&
        FirebaseAuth.instance.currentUser == null) {
      return BusinessSearchResult.fail(
        'Please log in again to search businesses.',
      );
    }

    try {
      final snap = await _loadShopDirectory();
      final out = <BusinessSummary>[];
      for (final d in snap.docs) {
        final data = d.data();
        final status = (data[AccountApproval.fieldStatus] as String?) ??
            AccountApproval.statusApproved;
        if (status != AccountApproval.statusApproved) continue;

        final name = ((data['name'] as String?) ?? '').trim();
        final code = ((data['code'] as String?) ?? '').trim();
        if (name.isEmpty) continue;
        if (!BusinessSearch.matches(
          name: name.toLowerCase(),
          code: code.toLowerCase(),
          query: q,
        )) {
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
      return BusinessSearchResult.ok(out.take(25).toList());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('searchApprovedBusinesses error: $e');
      }
      return BusinessSearchResult.fail(
        'Could not load businesses. Check your internet connection and '
        'try again.',
      );
    }
  }

  /// Shop directory for staff search. Prefer the server so a stale or
  /// empty local cache cannot hide approved businesses; fall back to
  /// cache when offline.
  Future<QuerySnapshot<Map<String, dynamic>>> _loadShopDirectory() async {
    final col = FirebaseFirestore.instance
        .collection(FirestorePaths.shopsCollection)
        .limit(200);
    try {
      return await col.get(const GetOptions(source: Source.server));
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        return col.get(const GetOptions(source: Source.cache));
      }
      rethrow;
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

enum _MemberLook { approved, pending, rejected, missing, unknown }
