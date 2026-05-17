import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/account_provider.dart';

/// Keeps the [accountStateProvider] subscribed for the lifetime of the
/// app so the GoRouter redirect always sees the latest approval state.
class AccountWatcher extends ConsumerWidget {
  final Widget child;

  const AccountWatcher({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accountStateProvider);
    return child;
  }
}
