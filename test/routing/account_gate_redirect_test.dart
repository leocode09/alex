import 'package:alex/models/account_state.dart';
import 'package:alex/routing/account_gate_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const signedOut = AccountState.signedOut;
  const noAccountMissingUid = AccountState.noAccount;
  const noAccount = AccountState(
    stage: AccountStage.noAccount,
    uid: 'user-1',
  );
  const unknown = AccountState.unknown;
  const approved = AccountState(
    stage: AccountStage.approved,
    uid: 'user-1',
    shopId: 'shop-1',
  );
  const pending = AccountState(
    stage: AccountStage.businessPending,
    uid: 'user-1',
    shopId: 'shop-1',
  );
  const firebaseDown = AccountState.firebaseDown;

  String? gate(AccountState account, String path) =>
      accountGateRedirect(account: account, path: path);

  List<String> chain(String startPath, Iterable<AccountState> accounts) {
    final visited = <String>[startPath];
    var path = startPath;
    for (final account in accounts) {
      final next = accountGateRedirect(account: account, path: path);
      if (next == null || next == path) {
        continue;
      }
      visited.add(next);
      path = next;
    }
    return visited;
  }

  group('accountGateRedirect', () {
    test('signed-out users stay on login / register', () {
      expect(gate(signedOut, '/account-login'), isNull);
      expect(gate(signedOut, '/account-register'), isNull);
      expect(gate(signedOut, '/'), '/account-login');
      expect(gate(signedOut, '/onboarding'), '/account-login');
      expect(gate(signedOut, '/sales'), '/account-login');
    });

    test('logged-in users with no shop stay on onboarding', () {
      expect(gate(noAccount, '/onboarding'), isNull);
      expect(gate(noAccount, '/onboarding/create-business'), isNull);
      expect(gate(noAccount, '/account-login'), '/onboarding');
      expect(gate(noAccount, '/'), '/onboarding');
    });

    test('noAccount without a uid is treated as signed-out', () {
      expect(noAccountMissingUid.effectiveGateStage, AccountStage.signedOut);
      expect(gate(noAccountMissingUid, '/account-login'), isNull);
      expect(gate(noAccountMissingUid, '/account-register'), isNull);
      expect(gate(noAccountMissingUid, '/onboarding'), '/account-login');
      expect(gate(noAccountMissingUid, '/sales'), '/account-login');
    });

    test('pending / rejected users stay on the approval screen', () {
      expect(gate(pending, '/pending-approval'), isNull);
      expect(gate(pending, '/account-login'), '/pending-approval');
      expect(gate(pending, '/onboarding'), '/pending-approval');
    });

    test('unknown stays on any account-gate page', () {
      expect(gate(unknown, '/account-login'), isNull);
      expect(gate(unknown, '/onboarding'), isNull);
      expect(gate(unknown, '/pending-approval'), isNull);
      expect(gate(unknown, '/sales'), '/account-login');
    });

    test('approved or firebase-down skip the approval gate', () {
      expect(gate(approved, '/sales'), isNull);
      expect(gate(approved, '/account-login'), isNull);
      expect(gate(firebaseDown, '/account-login'), isNull);
      expect(gate(firebaseDown, '/sales'), isNull);
    });

    test('admin routes always bypass the approval gate', () {
      expect(gate(signedOut, '/admin'), isNull);
      expect(gate(signedOut, '/admin-login'), isNull);
      expect(gate(noAccount, '/admin/shops'), isNull);
    });
  });

  group('redirect sequences', () {
    test('session-loss flicker cannot loop login and onboarding', () {
      // Historical bug: a detached shop snapshot emitted noAccount with
      // a null uid (router → /onboarding), then reattach emitted
      // signedOut (router → /account-login). go_router recorded
      // /account-login => /onboarding => /onboarding => /account-login.
      final visited = chain('/account-login', const [
        noAccountMissingUid,
        noAccountMissingUid,
        signedOut,
        noAccountMissingUid,
        signedOut,
      ]);
      expect(visited, ['/account-login']);
    });

    test('a real no-shop login still reaches onboarding once', () {
      final visited = chain('/account-login', const [signedOut, noAccount]);
      expect(visited, ['/account-login', '/onboarding']);
    });

    test('logout from onboarding returns to login without cycling', () {
      final visited = chain('/onboarding', const [noAccount, signedOut]);
      expect(visited, ['/onboarding', '/account-login']);
    });
  });
}
