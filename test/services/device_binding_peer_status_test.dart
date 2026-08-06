import 'package:alex/services/admin/device_registration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceBindingResult.peerGateStatus', () {
    test('keeps signed-out distinct from unregistered', () {
      const signedOut = DeviceBindingResult(
        DeviceBindingStatus.signedOut,
        'Your session expired. Please log in again.',
      );
      const unbound = DeviceBindingResult(
        DeviceBindingStatus.unbound,
        'This device has not been registered.',
      );

      expect(signedOut.peerGateStatus, 'sign_in_required');
      expect(unbound.peerGateStatus, 'device_not_registered');
      expect(signedOut.peerGateStatus, isNot(unbound.peerGateStatus));
    });

    test('maps conflict and unavailable distinctly', () {
      expect(
        const DeviceBindingResult(
          DeviceBindingStatus.conflict,
          'belongs to another account',
        ).peerGateStatus,
        'device_conflict',
      );
      expect(
        const DeviceBindingResult(
          DeviceBindingStatus.unavailable,
          'Cloud is unavailable.',
        ).peerGateStatus,
        'cloud_unavailable',
      );
      expect(
        const DeviceBindingResult(
          DeviceBindingStatus.bound,
          'ok',
        ).peerGateStatus,
        'ok',
      );
    });
  });
}
