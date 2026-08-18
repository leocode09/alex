import '../models/account_state.dart';

/// Approval-gate destination for [path], or `null` to stay put.
///
/// Mirrors the GoRouter account gate in `lib/routes.dart`. Kept as a
/// pure function so the `/account-login` ↔ `/onboarding` loop can be
/// regression-tested without spinning up Firebase or a widget tree.
String? accountGateRedirect({
  required AccountState account,
  required String path,
}) {
  if (account.allowsAppAccess) {
    return null;
  }
  if (path.startsWith('/admin')) {
    return null;
  }

  final isOnOnboarding = path.startsWith('/onboarding');
  final isOnPendingApproval = path == '/pending-approval';
  final isOnAccountLogin =
      path == '/account-login' || path == '/account-register';
  final isOnAccountGate =
      isOnOnboarding || isOnPendingApproval || isOnAccountLogin;

  switch (account.effectiveGateStage) {
    case AccountStage.signedOut:
      return isOnAccountLogin ? null : '/account-login';
    case AccountStage.noAccount:
      return isOnOnboarding ? null : '/onboarding';
    case AccountStage.businessPending:
    case AccountStage.staffPending:
    case AccountStage.businessRejected:
    case AccountStage.staffRejected:
      return isOnPendingApproval ? null : '/pending-approval';
    case AccountStage.unknown:
    case AccountStage.approved:
      return isOnAccountGate ? null : '/account-login';
  }
}
