import 'package:alex/helpers/identity_labels.dart';
import 'package:alex/models/account_state.dart';
import 'package:alex/services/identity_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await IdentityLabel.update('Device');
  });

  group('IdentityLabel', () {
    test('falls back to Device when nothing is cached', () async {
      await IdentityLabel.initialize();
      expect(IdentityLabel.current, IdentityLabel.fallback);
    });

    test('persists display name into identity and legacy LAN prefs', () async {
      await IdentityLabel.update('Maggie');
      expect(IdentityLabel.current, 'Maggie');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(IdentityLabel.preferenceKey), 'Maggie');
      expect(prefs.getString(IdentityLabel.legacyLanPreferenceKey), 'Maggie');
    });

    test('updateFromAccount ignores empty names', () async {
      await IdentityLabel.update('Maggie');
      await IdentityLabel.updateFromAccount(AccountState.signedOut);
      expect(IdentityLabel.current, 'Maggie');
    });

    test('updateFromAccount applies a signed-in display name', () async {
      await IdentityLabel.updateFromAccount(
        const AccountState(
          stage: AccountStage.approved,
          displayName: '  Kudzi  ',
        ),
      );
      expect(IdentityLabel.current, 'Kudzi');
    });

    test('never uses a blank update', () async {
      await IdentityLabel.update('Maggie');
      await IdentityLabel.update('   ');
      expect(IdentityLabel.current, 'Maggie');
    });
  });

  group('IdentityLabels', () {
    test('prefers deviceName over memberDisplayName', () {
      expect(
        IdentityLabels.deviceDisplayName({
          'deviceName': 'Maggie',
          'memberDisplayName': 'Other',
        }),
        'Maggie',
      );
    });

    test('falls back to memberDisplayName then Unregistered device', () {
      expect(
        IdentityLabels.deviceDisplayName({
          'memberDisplayName': 'Maggie',
        }),
        'Maggie',
      );
      expect(IdentityLabels.deviceDisplayName(const {}), 'Unregistered device');
    });

    test('formats Rwanda phone numbers for display', () {
      expect(
        IdentityLabels.formatPhoneForDisplay('0788123456'),
        '+250 788 123 456',
      );
      expect(
        IdentityLabels.formatPhoneForDisplay('+250788123456'),
        '+250 788 123 456',
      );
    });

    test('memberDisplayName never uses hardware ids as the title', () {
      expect(
        IdentityLabels.memberDisplayName(const {}, uid: 'abcdefghijklmnop'),
        'Unnamed member (abcdefgh)',
      );
    });
  });
}
