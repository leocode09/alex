/// The stage of a device's account workflow.
///
/// The app uses these stages to gate access to the POS:
///   - `unknown`: still loading state from Firestore.
///   - `noAccount`: this device has not yet created or joined a business.
///   - `businessPending`: the business owner registered a new shop and is
///     waiting for the system administrator to approve it.
///   - `businessRejected`: the system administrator rejected the
///     business; the owner can resubmit.
///   - `staffPending`: the staff member has submitted a join request to
///     an existing business and is waiting for the owner to approve it.
///   - `staffRejected`: the owner rejected the staff join request.
///   - `approved`: both the shop and this device's member doc are
///     approved; the POS is fully usable.
enum AccountStage {
  unknown,
  noAccount,
  businessPending,
  businessRejected,
  staffPending,
  staffRejected,
  approved,
}

enum AccountRole { owner, staff }

/// Snapshot of the device's current account/approval state.
class AccountState {
  final AccountStage stage;
  final String? shopId;
  final String? shopName;
  final String? shopCode;
  final AccountRole? role;
  final String? displayName;
  final String? phone;
  final String? rejectionReason;

  /// True when Firebase is not initialized on this build. Used to let
  /// the app fall back to the existing offline-friendly behaviour
  /// instead of locking the user out.
  final bool firebaseUnavailable;

  const AccountState({
    required this.stage,
    this.shopId,
    this.shopName,
    this.shopCode,
    this.role,
    this.displayName,
    this.phone,
    this.rejectionReason,
    this.firebaseUnavailable = false,
  });

  static const AccountState unknown =
      AccountState(stage: AccountStage.unknown);

  static const AccountState noAccount =
      AccountState(stage: AccountStage.noAccount);

  static const AccountState firebaseDown = AccountState(
    stage: AccountStage.unknown,
    firebaseUnavailable: true,
  );

  /// Whether the POS is reachable. When Firebase is missing on this
  /// build the app degrades to local-only and the gate stays open
  /// (mirrors the existing license behaviour).
  bool get allowsAppAccess =>
      firebaseUnavailable || stage == AccountStage.approved;

  bool get isPending =>
      stage == AccountStage.businessPending ||
      stage == AccountStage.staffPending;

  bool get isRejected =>
      stage == AccountStage.businessRejected ||
      stage == AccountStage.staffRejected;

  bool get isOwner => role == AccountRole.owner;
  bool get isStaff => role == AccountRole.staff;
}

/// Outcome of an account-related action (register business, submit
/// join request, owner approval, etc.).
class AccountActionResult {
  final bool success;
  final String message;

  const AccountActionResult._({required this.success, required this.message});

  factory AccountActionResult.ok(String message) =>
      AccountActionResult._(success: true, message: message);

  factory AccountActionResult.fail(String message) =>
      AccountActionResult._(success: false, message: message);
}

/// Lightweight summary of an approved business returned by the staff
/// search lookup.
class BusinessSummary {
  final String id;
  final String name;
  final String code;
  final String? ownerName;

  const BusinessSummary({
    required this.id,
    required this.name,
    required this.code,
    this.ownerName,
  });
}

/// Constants shared between the service and the security rules /
/// admin UI for the new approval workflow.
class AccountApproval {
  const AccountApproval._();

  static const String fieldStatus = 'approvalStatus';
  static const String fieldRequestedAt = 'approvalRequestedAt';
  static const String fieldApprovedAt = 'approvedAt';
  static const String fieldApprovedBy = 'approvedBy';
  static const String fieldRejectedAt = 'rejectedAt';
  static const String fieldRejectedBy = 'rejectedBy';
  static const String fieldRejectionReason = 'rejectionReason';

  static const String statusApproved = 'approved';
  static const String statusPendingSystemAdmin = 'pendingSystemAdmin';
  static const String statusPendingOwner = 'pendingOwner';
  static const String statusRejected = 'rejected';

  static const String roleOwner = 'owner';
  static const String roleStaff = 'staff';
}
