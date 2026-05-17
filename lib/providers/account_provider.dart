import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_state.dart';
import '../services/cloud/account_service.dart';

/// Singleton [AccountService] exposed as a provider.
final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(),
);

/// Live stream of the device's [AccountState]. Always emits — starts
/// with the cached state (or [AccountState.unknown]) and updates as the
/// shop / member docs change in Firestore.
final accountStateProvider = StreamProvider<AccountState>((ref) {
  final service = ref.watch(accountServiceProvider);
  return service.watch();
});

/// Synchronously-resolvable convenience that the router redirect can
/// read without awaiting the stream.
final currentAccountStateProvider = Provider<AccountState>((ref) {
  final async = ref.watch(accountStateProvider);
  return async.maybeWhen(
    data: (s) => s,
    orElse: () => ref.watch(accountServiceProvider).current,
  );
});
