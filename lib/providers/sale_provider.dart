import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../repositories/sale_repository.dart';
import 'customer_provider.dart';
import 'sync_events_provider.dart';

// Repository provider
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository();
});

// State provider to track which receipt is being edited
final editingReceiptProvider = StateProvider<Sale?>((ref) => null);

// All sales provider
final salesProvider = FutureProvider<List<Sale>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getAllSales();
});

// Today's sales provider
final todaysSalesProvider = FutureProvider<List<Sale>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTodaysSales();
});

// Today's sales count provider
final todaysSalesCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTodaysSalesCount();
});

// Today's revenue provider
final todaysRevenueProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTodaysRevenue();
});

// Total revenue provider
final totalRevenueProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTotalRevenue();
});

// Total sales count provider
final totalSalesCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTotalSalesCount();
});

// Top selling products provider
final topSellingProductsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTopSellingProducts(limit: 10);
});

// Weekly sales provider
final weeklySalesProvider = FutureProvider<List<Sale>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getWeeklySales();
});

// Weekly revenue provider
final weeklyRevenueProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getWeeklyRevenue();
});

// Yesterday's sales provider
final yesterdaysSalesProvider = FutureProvider<List<Sale>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getYesterdaysSales();
});

// Yesterday's revenue provider
final yesterdaysRevenueProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getYesterdaysRevenue();
});

// Yesterday's sales count provider
final yesterdaysSalesCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getYesterdaysSalesCount();
});

// Last week revenue provider
final lastWeekRevenueProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getLastWeekRevenue();
});

/// Aggregate snapshot for the customer management dashboard. One per
/// `Customer`, with derived totals computed from the global sale list.
class CustomerSummary {
  final Customer customer;
  final double amountDue;
  final int unpaidCount;
  final DateTime? lastSaleAt;

  const CustomerSummary({
    required this.customer,
    required this.amountDue,
    required this.unpaidCount,
    required this.lastSaleAt,
  });
}

/// Sales (oldest first) where the customer still owes money.
final customerUnpaidSalesProvider =
    FutureProvider.family<List<Sale>, String>((ref, customerId) async {
  final sales = await ref.watch(salesProvider.future);
  final unpaid = sales
      .where((s) => s.customerId == customerId && s.amountDue > 0.000001)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return unpaid;
});

/// Total amount currently owed by [customerId] across every sale on file.
final customerAmountDueProvider =
    FutureProvider.family<double, String>((ref, customerId) async {
  final sales = await ref.watch(salesProvider.future);
  return sales
      .where((s) => s.customerId == customerId)
      .fold<double>(0.0, (sum, s) => sum + s.amountDue);
});

/// Per-customer summary (joined with the sale ledger). Drives the
/// management dashboard and the sortable customer list.
final customerSummariesProvider =
    FutureProvider<List<CustomerSummary>>((ref) async {
  final customers = await ref.watch(customersProvider.future);
  final sales = await ref.watch(salesProvider.future);
  return customers.map((c) {
    final theirs = sales.where((s) => s.customerId == c.id).toList();
    double due = 0;
    int unpaid = 0;
    DateTime? last;
    for (final s in theirs) {
      due += s.amountDue;
      if (s.amountDue > 0.000001) unpaid++;
      if (last == null || s.createdAt.isAfter(last)) last = s.createdAt;
    }
    return CustomerSummary(
      customer: c,
      amountDue: due,
      unpaidCount: unpaid,
      lastSaleAt: last,
    );
  }).toList();
});

/// Sum of every customer's outstanding balance.
final totalAmountDueProvider = FutureProvider<double>((ref) async {
  final summaries = await ref.watch(customerSummariesProvider.future);
  return summaries.fold<double>(0.0, (sum, s) => sum + s.amountDue);
});

/// Sum of every customer's available store credit.
final totalCreditOutstandingProvider = FutureProvider<double>((ref) async {
  final customers = await ref.watch(customersProvider.future);
  return customers.fold<double>(0.0, (sum, c) => sum + c.creditBalance);
});

/// Sum of bonuses earned across all customers.
final totalBonusEarnedProvider = FutureProvider<double>((ref) async {
  final customers = await ref.watch(customersProvider.future);
  return customers.fold<double>(0.0, (sum, c) => sum + c.totalBonusEarned);
});

// Today's profit provider (sum of item-level profits from stored costPrice)
final todaysProfitProvider = FutureProvider<double?>((ref) async {
  final sales = await ref.watch(todaysSalesProvider.future);
  double total = 0;
  bool hasCost = false;
  for (final sale in sales) {
    for (final item in sale.items) {
      final p = item.profit;
      if (p != null) {
        total += p;
        hasCost = true;
      }
    }
  }
  return hasCost ? total : null;
});
