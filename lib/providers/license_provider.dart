import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/license_policy.dart';
import '../services/admin/license_service.dart';

/// Singleton [LicenseService] exposed as a provider.
final licenseServiceProvider = Provider<LicenseService>(
  (ref) => LicenseService(),
);

/// Live policy stream. Always emits — starts with either the cached
/// policy or [LicensePolicy.unrestricted], then updates as the shop and
/// device docs change in Firestore.
final licensePolicyProvider = StreamProvider<LicensePolicy>((ref) {
  final service = ref.watch(licenseServiceProvider);
  return service.watch();
});

/// Read-only convenience: the current policy, synchronously resolved
/// from the stream (falls back to the service's cached value while the
/// stream is warming up).
final currentLicensePolicyProvider = Provider<LicensePolicy>((ref) {
  final async = ref.watch(licensePolicyProvider);
  return async.maybeWhen(
    data: (policy) => policy,
    orElse: () => ref.watch(licenseServiceProvider).current,
  );
});
