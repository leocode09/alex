import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/license_provider.dart';

/// Listens to the live [LicensePolicy] stream. This widget exists
/// mainly to keep the [licensePolicyProvider] alive for the whole app
/// lifecycle so the [GoRouter] redirect always has an up-to-date policy
/// to query, even on screens that don't read the provider directly.
class LicenseWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const LicenseWatcher({super.key, required this.child});

  @override
  ConsumerState<LicenseWatcher> createState() => _LicenseWatcherState();
}

class _LicenseWatcherState extends ConsumerState<LicenseWatcher> {
  @override
  Widget build(BuildContext context) {
    // Subscribe so the provider stays active and emits updates as the
    // remote shop/device docs change. The value is consumed by
    // [currentLicensePolicyProvider] at the consumption sites (router
    // redirect, gate helper, lock screen).
    ref.watch(licensePolicyProvider);
    return widget.child;
  }
}
