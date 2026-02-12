import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'sync_events_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(expenseRepositoryProvider);
  return await repository.getAllExpenses();
});

final totalExpensesProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(expenseRepositoryProvider);
  return await repository.getTotalExpenses();
});
