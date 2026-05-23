import 'package:cloud_firestore/cloud_firestore.dart';

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
    final nowIso = DateTime.now().toIso8601String();
    final trimmedName = displayName.trim();
    final trimmedPhone = phoneNumber?.trim();

    try {
      final snap = await memberRef.get();
      if (!snap.exists) {
        await memberRef.set(_pendingStaffPayload(
          uid: uid,
          displayName: trimmedName,
          phone: trimmedPhone,
          joinedAt: nowIso,
          requestedAt: nowIso,
        ));
        return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.created);
      }

      final data = snap.data() ?? <String, dynamic>{};
      final role =
          (data['role'] as String?) ?? AccountApproval.roleStaff;
      final status = (data[AccountApproval.fieldStatus] as String?) ??
          AccountApproval.statusApproved;

      if (role == AccountApproval.roleOwner) {
        return StaffJoinWriteResult.fail(
          'You are the owner of this business. Sign in as owner instead.',
        );
      }

      if (status == AccountApproval.statusApproved) {
        return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.alreadyMember);
      }

      if (status == AccountApproval.statusPendingOwner) {
        await memberRef.update(_profilePatch(
          displayName: trimmedName,
          phone: trimmedPhone,
          requestedAt: nowIso,
        ));
        return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.updatedPending);
      }

      if (status == AccountApproval.statusRejected) {
        await memberRef.update({
          ..._pendingStaffPayload(
            uid: uid,
            displayName: trimmedName,
            phone: trimmedPhone,
            joinedAt: (data['joinedAt'] as String?) ?? nowIso,
            requestedAt: nowIso,
          ),
          AccountApproval.fieldRejectedAt: FieldValue.delete(),
          AccountApproval.fieldRejectedBy: FieldValue.delete(),
          AccountApproval.fieldRejectionReason: FieldValue.delete(),
        });
        return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.resubmitted);
      }

      return StaffJoinWriteResult.fail(
        'Unable to submit a join request for your current membership status.',
      );
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
