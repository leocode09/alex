import 'package:alex/models/account_state.dart';
import 'package:alex/services/shop_peer_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShopPeerGate.evaluate', () {
    test('allows an approved member with a shop id', () {
      const account = AccountState(
        stage: AccountStage.approved,
        shopId: 'shop-a',
      );

      final result = ShopPeerGate.evaluate(account: account);

      expect(result.isAllowed, isTrue);
      expect(result.shopId, 'shop-a');
      expect(result.statusCode, isNull);
    });

    test('allows an approved member using the cached shop id', () {
      const account = AccountState(stage: AccountStage.approved);

      final result = ShopPeerGate.evaluate(
        account: account,
        cachedShopId: 'shop-cached',
      );

      expect(result.isAllowed, isTrue);
      expect(result.shopId, 'shop-cached');
    });

    test('allows local sharing when cloud is down but a shop is linked', () {
      const account = AccountState(
        stage: AccountStage.unknown,
        firebaseUnavailable: true,
      );

      final result = ShopPeerGate.evaluate(
        account: account,
        cachedShopId: 'shop-offline',
      );

      expect(result.isAllowed, isTrue);
      expect(result.shopId, 'shop-offline');
    });

    test('does not treat a pending staff member as approved', () {
      const account = AccountState(
        stage: AccountStage.staffPending,
        shopId: 'shop-a',
      );

      final result = ShopPeerGate.evaluate(account: account);

      expect(result.isAllowed, isFalse);
      expect(result.statusCode, 'account_not_approved');
      expect(result.message, contains('Waiting for approval'));
    });

    test('does not start sharing when cloud is down with no shop cache', () {
      const account = AccountState(
        stage: AccountStage.unknown,
        firebaseUnavailable: true,
      );

      final result = ShopPeerGate.evaluate(account: account);

      expect(result.isAllowed, isFalse);
      expect(result.statusCode, 'account_not_approved');
      expect(result.message, contains('no linked shop'));
    });

    test('asks a signed-out user to log in instead of blaming approval', () {
      const account = AccountState(stage: AccountStage.signedOut);

      final result = ShopPeerGate.evaluate(account: account);

      expect(result.isAllowed, isFalse);
      expect(result.statusCode, 'sign_in_required');
    });
  });

  group('AccountState.canShareWithShopPeers', () {
    test('is true for approved members with a shop', () {
      const account = AccountState(
        stage: AccountStage.approved,
        shopId: 'shop-a',
      );
      expect(account.canShareWithShopPeers, isTrue);
    });

    test('is true when firebase is down and a shop is already linked', () {
      const account = AccountState(
        stage: AccountStage.unknown,
        shopId: 'shop-a',
        firebaseUnavailable: true,
      );
      expect(account.canShareWithShopPeers, isTrue);
    });

    test('is false for approved members with no shop id', () {
      const account = AccountState(stage: AccountStage.approved);
      expect(account.canShareWithShopPeers, isFalse);
    });
  });
}
