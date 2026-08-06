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

// All sales provider — the single source of truth for the sale ledger.
// The metric providers below derive from this shared list so a sync event
// triggers one repository read instead of a dozen.
final salesProvider = FutureProvider<List<Sale>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getAllSales();
});

// Mirrors SaleRepository.getSalesByDateRange semantics
// (created_at > start AND created_at < end).
bool _inRange(Sale sale, DateTime start, DateTime end) =>
    sale.createdAt.isAfter(start) && sale.createdAt.isBefore(end);

DateTime _startOfDay(DateTime day) => DateTime(day.year, day.month, day.day);

DateTime _endOfDay(DateTime day) =>
    DateTime(day.year, day.month, day.day, 23, 59, 59);

// Today's sales provider
final todaysSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  final now = DateTime.now();
  final start = _startOfDay(now);
  final end = _endOfDay(now);
  return sales.where((s) => _inRange(s, start, end)).toList();
});

// Today's sales count provider
final todaysSalesCountProvider = FutureProvider<int>((ref) async {
  final sales = await ref.watch(todaysSalesProvider.future);
  return sales.length;
});

// Today's revenue provider
final todaysRevenueProvider = FutureProvider<double>((ref) async {
  final sales = await ref.watch(todaysSalesProvider.future);
  return sales.fold<double>(0.0, (sum, s) => sum + s.total);
});

// Total revenue provider
final totalRevenueProvider = FutureProvider<double>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  return sales.fold<double>(0.0, (sum, s) => sum + s.total);
});

// Total sales count provider
final totalSalesCountProvider = FutureProvider<int>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  return sales.length;
});

// Top selling products provider (product name -> base units sold, top 10)
final topSellingProductsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  final Map<String, int> productCounts = {};
  for (final sale in sales) {
    for (final item in sale.items) {
      productCounts[item.productName] =
          (productCounts[item.productName] ?? 0) + item.baseUnitsSold;
    }
  }
  final sortedEntries = productCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sortedEntries.take(10));
});

// Revenue per product name across every sale (drives the dashboard's
// top-products list). Computed once per sales-list change instead of in
// the widget's build().
final productRevenueByNameProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  final Map<String, double> revenues = {};
  for (final sale in sales) {
    for (final item in sale.items) {
      revenues[item.productName] =
          (revenues[item.productName] ?? 0) + (item.price * item.quantity);
    }
  }
  return revenues;
});

// Weekly sales provider (last 7 days including today)
final weeklySalesProvider = FutureProvider<List<Sale>>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  final now = DateTime.now();
  final start = _startOfDay(now).subtract(const Duration(days: 6));
  final end = _endOfDay(now);
  return sales.where((s) => _inRange(s, start, end)).toList();
});

// Weekly revenue provider
final weeklyRevenueProvider = FutureProvider<double>((ref) async {
  final sales = await ref.watch(weeklySalesProvider.future);
  return sales.fold<double>(0.0, (sum, s) => sum + s.total);
});

// Yesterday's sales provider
final yesterdaysSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final start = _startOfDay(yesterday);
  final end = _endOfDay(yesterday);
  return sales.where((s) => _inRange(s, start, end)).toList();
});

// Yesterday's revenue provider
final yesterdaysRevenueProvider = FutureProvider<double>((ref) async {
  final sales = await ref.watch(yesterdaysSalesProvider.future);
  return sales.fold<double>(0.0, (sum, s) => sum + s.total);
});

// Yesterday's sales count provider
final yesterdaysSalesCountProvider = FutureProvider<int>((ref) async {
  final sales = await ref.watch(yesterdaysSalesProvider.future);
  return sales.length;
});

// Last week revenue provider (days 13..7 before today)
final lastWeekRevenueProvider = FutureProvider<double>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  final now = DateTime.now();
  final start = _startOfDay(now).subtract(const Duration(days: 13));
  final end = _startOfDay(now).subtract(const Duration(days: 7));
  return sales
      .where((s) => _inRange(s, start, end))
      .fold<double>(0.0, (sum, s) => sum + s.total);
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

/// Sales bucketed by customer id in a single pass over the ledger. Shared by
/// the per-customer providers below so none of them rescans the full list
/// once per customer.
final _salesByCustomerProvider =
    FutureProvider<Map<String, List<Sale>>>((ref) async {
  final sales = await ref.watch(salesProvider.future);
  final Map<String, List<Sale>> byCustomer = {};
  for (final sale in sales) {
    final customerId = sale.customerId;
    if (customerId == null) continue;
    (byCustomer[customerId] ??= []).add(sale);
  }
  return byCustomer;
});

/// Sales (oldest first) where the customer still owes money.
final customerUnpaidSalesProvider =
    FutureProvider.family<List<Sale>, String>((ref, customerId) async {
  final salesByCustomer = await ref.watch(_salesByCustomerProvider.future);
  final unpaid = (salesByCustomer[customerId] ?? const <Sale>[])
      .where((s) => s.amountDue > 0.000001)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return unpaid;
});

/// Total amount currently owed by [customerId] across every sale on file.
final customerAmountDueProvider =
    FutureProvider.family<double, String>((ref, customerId) async {
  final salesByCustomer = await ref.watch(_salesByCustomerProvider.future);
  return (salesByCustomer[customerId] ?? const <Sale>[])
      .fold<double>(0.0, (sum, s) => sum + s.amountDue);
});

/// Per-customer summary (joined with the sale ledger). Drives the
/// management dashboard and the sortable customer list.
final customerSummariesProvider =
    FutureProvider<List<CustomerSummary>>((ref) async {
  final customers = await ref.watch(customersProvider.future);
  final salesByCustomer = await ref.watch(_salesByCustomerProvider.future);
  return customers.map((c) {
    final theirs = salesByCustomer[c.id] ?? const <Sale>[];
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
