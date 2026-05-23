import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/account_state.dart';

/// Outcome of writing a staff join request member doc.
enum StaffJoinWriteOutcome {
  created,
  updatedPending,
  resubmitted,
  alreadyMember,
}

class StaffJoinWriteResult {
  final bool success;
  final StaffJoinWriteOutcome? outcome;
  final String? errorMessage;

  const StaffJoinWriteResult._({
    required this.success,
    this.outcome,
    this.errorMessage,
  });

  factory StaffJoinWriteResult.ok(StaffJoinWriteOutcome outcome) {
    return StaffJoinWriteResult._(success: true, outcome: outcome);
  }

  factory StaffJoinWriteResult.fail(String message) {
    return StaffJoinWriteResult._(success: false, errorMessage: message);
  }

  factory StaffJoinWriteResult.fromFirebase(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return StaffJoinWriteResult.fail(
        'Could not send join request. Ask the shop owner to update '
        'Firestore rules, or contact support.',
      );
    }
    return StaffJoinWriteResult.fail('Failed to submit request: $e');
  }
}

/// Writes `/shops/{shopId}/members/{uid}` for staff onboarding without
/// blind merge, so Firestore create vs update rules apply correctly.
class StaffJoinRequestWriter {
  const StaffJoinRequestWriter._();

  static Future<StaffJoinWriteResult> upsert({
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String uid,
    String displayName = '',
    String? phoneNumber,
  }) async {
    final trimmedName = displayName.trim();
    final trimmedPhone = phoneNumber?.trim();

    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await memberRef.get();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        return StaffJoinWriteResult.fromFirebase(e);
      }
      if (kDebugMode) {
        debugPrint(
          'StaffJoinRequestWriter: member get denied; treating as missing.',
        );
      }
    }

    if (snap == null || !snap.exists) {
      return _createPending(
        memberRef: memberRef,
        uid: uid,
        displayName: trimmedName,
        phoneNumber: trimmedPhone,
      );
    }

    final data = snap.data() ?? <String, dynamic>{};
    final role = (data['role'] as String?) ?? AccountApproval.roleStaff;
    final status = _memberStatus(data);

    if (role == AccountApproval.roleOwner) {
      return StaffJoinWriteResult.fail(
        'You are the owner of this business. Sign in as owner instead.',
      );
    }

    if (status == AccountApproval.statusApproved) {
      return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.alreadyMember);
    }

    if (status == AccountApproval.statusPendingOwner) {
      return _updatePendingProfile(
        memberRef: memberRef,
        uid: uid,
        displayName: trimmedName,
        phoneNumber: trimmedPhone,
        joinedAt: (data['joinedAt'] as String?) ??
            DateTime.now().toIso8601String(),
      );
    }

    if (status == AccountApproval.statusRejected) {
      return _resubmitAfterRejection(
        memberRef: memberRef,
        uid: uid,
        displayName: trimmedName,
        phoneNumber: trimmedPhone,
        joinedAt: (data['joinedAt'] as String?) ??
            DateTime.now().toIso8601String(),
      );
    }

    return _resetAndCreate(
      memberRef: memberRef,
      uid: uid,
      displayName: trimmedName,
      phoneNumber: trimmedPhone,
    );
  }

  static String _memberStatus(Map<String, dynamic> data) {
    return (data[AccountApproval.fieldStatus] as String?) ??
        AccountApproval.statusApproved;
  }

  static Future<StaffJoinWriteResult> _createPending({
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String uid,
    required String displayName,
    required String? phoneNumber,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    try {
      await memberRef.set(_pendingStaffPayload(
        uid: uid,
        displayName: displayName,
        phone: phoneNumber,
        joinedAt: nowIso,
        requestedAt: nowIso,
      ));
      return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.created);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        return StaffJoinWriteResult.fromFirebase(e);
      }
      return _resetAndCreate(
        memberRef: memberRef,
        uid: uid,
        displayName: displayName,
        phoneNumber: phoneNumber,
      );
    }
  }

  static Future<StaffJoinWriteResult> _updatePendingProfile({
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String uid,
    required String displayName,
    required String? phoneNumber,
    required String joinedAt,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    try {
      await memberRef.update(_profilePatch(
        displayName: displayName,
        phone: phoneNumber,
        requestedAt: nowIso,
      ));
      return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.updatedPending);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        return StaffJoinWriteResult.fromFirebase(e);
      }
      return _resetAndCreate(
        memberRef: memberRef,
        uid: uid,
        displayName: displayName,
        phoneNumber: phoneNumber,
        joinedAt: joinedAt,
      );
    }
  }

  static Future<StaffJoinWriteResult> _resubmitAfterRejection({
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String uid,
    required String displayName,
    required String? phoneNumber,
    required String joinedAt,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    try {
      await memberRef.update({
        ..._pendingStaffPayload(
          uid: uid,
          displayName: displayName,
          phone: phoneNumber,
          joinedAt: joinedAt,
          requestedAt: nowIso,
        ),
        AccountApproval.fieldRejectedAt: FieldValue.delete(),
        AccountApproval.fieldRejectedBy: FieldValue.delete(),
        AccountApproval.fieldRejectionReason: FieldValue.delete(),
      });
      return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.resubmitted);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        return StaffJoinWriteResult.fromFirebase(e);
      }
      return _resetAndCreate(
        memberRef: memberRef,
        uid: uid,
        displayName: displayName,
        phoneNumber: phoneNumber,
        joinedAt: joinedAt,
      );
    }
  }

  /// Deletes the caller's own member doc (allowed by rules) and creates a
  /// fresh pending staff request. Recovers from legacy merge/update states.
  static Future<StaffJoinWriteResult> _resetAndCreate({
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String uid,
    required String displayName,
    required String? phoneNumber,
    String? joinedAt,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    try {
      await memberRef.delete();
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('StaffJoinRequestWriter: delete before recreate failed: $e');
      }
    }

    try {
      await memberRef.set(_pendingStaffPayload(
        uid: uid,
        displayName: displayName,
        phone: phoneNumber,
        joinedAt: joinedAt ?? nowIso,
        requestedAt: nowIso,
      ));
      return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.created);
    } on FirebaseException catch (e) {
      return StaffJoinWriteResult.fromFirebase(e);
    }
  }

  static Map<String, dynamic> _pendingStaffPayload({
    required String uid,
    required String displayName,
    required String? phone,
    required String joinedAt,
    required String requestedAt,
  }) {
    return {
      'uid': uid,
      'role': AccountApproval.roleStaff,
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'joinedAt': joinedAt,
      AccountApproval.fieldStatus: AccountApproval.statusPendingOwner,
      AccountApproval.fieldRequestedAt: requestedAt,
    };
  }

  static Map<String, dynamic> _profilePatch({
    required String displayName,
    required String? phone,
    required String requestedAt,
  }) {
    return {
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      AccountApproval.fieldRequestedAt: requestedAt,
    };
  }
}
