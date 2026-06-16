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

/// Writes `/shops/{shopId}/members/{uid}` for staff onboarding.
///
/// With a stable phone-keyed identity the member doc is either missing
/// (create a fresh pending request) or already belongs to this user
/// (update it back to pending, clearing any rejection). No
/// permission-denied recovery dance is needed anymore.
class StaffJoinRequestWriter {
  const StaffJoinRequestWriter._();

  static Future<StaffJoinWriteResult> upsert({
    required DocumentReference<Map<String, dynamic>> memberRef,
    required String uid,
    String displayName = '',
    String? phoneNumber,
  }) async {
    final name = displayName.trim();
    final phone = phoneNumber?.trim();
    final nowIso = DateTime.now().toIso8601String();

    try {
      final snap = await memberRef.get();

      if (!snap.exists) {
        await memberRef.set(_pendingPayload(
          uid: uid,
          displayName: name,
          phone: phone,
          joinedAt: nowIso,
          requestedAt: nowIso,
        ));
        return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.created);
      }

      final data = snap.data() ?? <String, dynamic>{};
      final role = (data['role'] as String?) ?? AccountApproval.roleStaff;
      final status = (data[AccountApproval.fieldStatus] as String?) ??
          AccountApproval.statusApproved;

      if (role == AccountApproval.roleOwner) {
        return StaffJoinWriteResult.fail(
          'You are the owner of this business.',
        );
      }
      if (status == AccountApproval.statusApproved) {
        return StaffJoinWriteResult.ok(StaffJoinWriteOutcome.alreadyMember);
      }

      final wasRejected = status == AccountApproval.statusRejected;
      await memberRef.update({
        ..._pendingPayload(
          uid: uid,
          displayName: name,
          phone: phone,
          joinedAt: (data['joinedAt'] as String?) ?? nowIso,
          requestedAt: nowIso,
        ),
        if (wasRejected) ...{
          AccountApproval.fieldRejectedAt: FieldValue.delete(),
          AccountApproval.fieldRejectedBy: FieldValue.delete(),
          AccountApproval.fieldRejectionReason: FieldValue.delete(),
        },
      });
      return StaffJoinWriteResult.ok(
        wasRejected
            ? StaffJoinWriteOutcome.resubmitted
            : StaffJoinWriteOutcome.updatedPending,
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('StaffJoinRequestWriter.upsert error: ${e.code}');
      }
      return StaffJoinWriteResult.fromFirebase(e);
    }
  }

  static Map<String, dynamic> _pendingPayload({
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
}
