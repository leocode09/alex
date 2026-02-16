import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_history_record.dart';
import '../models/money_account.dart';
import '../repositories/money_repository.dart';
import 'sync_events_provider.dart';

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) {
  return MoneyRepository();
});

final moneyAccountsProvider = FutureProvider<List<MoneyAccount>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(moneyRepositoryProvider);
  return repository.getAllAccounts();
});

final moneyTotalBalanceProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(moneyRepositoryProvider);
  return repository.getTotalBalance();
});

final moneyHistoryProvider = FutureProvider<List<AccountHistoryRecord>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(moneyRepositoryProvider);
  return repository.getAllHistory();
});

final accountMoneyHistoryProvider =
    FutureProvider.family<List<AccountHistoryRecord>, String>((ref, accountId) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(moneyRepositoryProvider);
  return repository.getHistoryForAccount(accountId);
});
