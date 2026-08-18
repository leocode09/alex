import 'package:alex/models/account_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountState.effectiveGateStage', () {
    test('keeps noAccount when a uid is present', () {
      const state = AccountState(
        stage: AccountStage.noAccount,
        uid: 'user-1',
      );
      expect(state.hasUid, isTrue);
      expect(state.effectiveGateStage, AccountStage.noAccount);
    });

    test('treats noAccount without a uid as signed-out', () {
      expect(AccountState.noAccount.hasUid, isFalse);
      expect(
        AccountState.noAccount.effectiveGateStage,
        AccountStage.signedOut,
      );
      expect(
        const AccountState(stage: AccountStage.noAccount, uid: '  ')
            .effectiveGateStage,
        AccountStage.signedOut,
      );
    });
  });

  group('AccountState equality', () {
    test('value-compares so duplicate emits can be skipped', () {
      const a = AccountState(
        stage: AccountStage.signedOut,
      );
      const b = AccountState(
        stage: AccountStage.signedOut,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(AccountState.noAccount));
    });
  });
}
