import '../models/account_state.dart';

/// Outcome of the LAN / Wi-Fi Direct shop membership gate.
class ShopPeerGateResult {
  final String? shopId;
  final String? statusCode;
  final String? message;

  const ShopPeerGateResult._({
    this.shopId,
    this.statusCode,
    this.message,
  });

  factory ShopPeerGateResult.allow(String shopId) =>
      ShopPeerGateResult._(shopId: shopId);

  factory ShopPeerGateResult.deny({
    required String statusCode,
    required String message,
  }) =>
      ShopPeerGateResult._(statusCode: statusCode, message: message);

  bool get isAllowed {
    final id = shopId?.trim();
    return id != null && id.isNotEmpty && statusCode == null;
  }
}

/// Decides whether this device may start shop-scoped peer sync.
///
/// Team management can show a staff member as approved in Firestore while
/// this device still has [AccountStage.unknown] (Firebase down, cache not
/// yet applied, or attach still in flight). Callers should pass the local
/// shop cache so an approved teammate is not blocked with "Account not
/// approved".
class ShopPeerGate {
  const ShopPeerGate._();

  static ShopPeerGateResult evaluate({
    required AccountState account,
    String? cachedShopId,
  }) {
    final shopId = _firstShopId(account.linkedShopId, cachedShopId);
    if (shopId != null) {
      if (account.stage == AccountStage.approved ||
          account.firebaseUnavailable) {
        return ShopPeerGateResult.allow(shopId);
      }
    }

    switch (account.stage) {
      case AccountStage.signedOut:
        return ShopPeerGateResult.deny(
          statusCode: 'sign_in_required',
          message: 'Your session expired. Please log in again.',
        );
      case AccountStage.staffPending:
      case AccountStage.businessPending:
        return ShopPeerGateResult.deny(
          statusCode: 'account_not_approved',
          message: 'Waiting for approval before LAN sharing can start.',
        );
      case AccountStage.staffRejected:
      case AccountStage.businessRejected:
        return ShopPeerGateResult.deny(
          statusCode: 'account_not_approved',
          message: 'This account was not approved for LAN sharing.',
        );
      case AccountStage.noAccount:
        return ShopPeerGateResult.deny(
          statusCode: 'account_not_approved',
          message: 'Join this shop on this device before starting LAN sharing.',
        );
      case AccountStage.unknown:
        if (account.firebaseUnavailable) {
          return ShopPeerGateResult.deny(
            statusCode: 'account_not_approved',
            message: 'This device has no linked shop yet. Connect to the '
                'internet once so your approved account can be restored.',
          );
        }
        return ShopPeerGateResult.deny(
          statusCode: 'account_not_approved',
          message: 'Still loading your shop account. Tap Start Sharing again.',
        );
      case AccountStage.approved:
        return ShopPeerGateResult.deny(
          statusCode: 'account_not_approved',
          message: 'Your account is approved, but this device has no shop '
              'linked for LAN sharing.',
        );
    }
  }

  static String? _firstShopId(String? primary, String? fallback) {
    final first = primary?.trim();
    if (first != null && first.isNotEmpty) return first;
    final second = fallback?.trim();
    if (second != null && second.isNotEmpty) return second;
    return null;
  }
}
