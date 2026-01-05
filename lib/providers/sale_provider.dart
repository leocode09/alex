import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import '../repositories/sale_repository.dart';

// Repository provider
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository();
});

// State provider to track which receipt is being edited
final editingReceiptProvider = StateProvider<Sale?>((ref) => null);

// All sales provider
final salesProvider = FutureProvider<List<Sale>>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getAllSales();
});

// Today's sales provider
final todaysSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTodaysSales();
});

// Today's sales count provider
final todaysSalesCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTodaysSalesCount();
});

// Today's revenue provider
final todaysRevenueProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTodaysRevenue();
});

// Total revenue provider
final totalRevenueProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTotalRevenue();
});

// Total sales count provider
final totalSalesCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTotalSalesCount();
});

// Top selling products provider
final topSellingProductsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getTopSellingProducts(limit: 10);
});

// Weekly sales provider
final weeklySalesProvider = FutureProvider<List<Sale>>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getWeeklySales();
});

// Weekly revenue provider
final weeklyRevenueProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getWeeklyRevenue();
});

// Yesterday's sales provider
final yesterdaysSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getYesterdaysSales();
});

// Yesterday's revenue provider
final yesterdaysRevenueProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getYesterdaysRevenue();
});

// Yesterday's sales count provider
final yesterdaysSalesCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getYesterdaysSalesCount();
});

// Last week revenue provider
final lastWeekRevenueProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(saleRepositoryProvider);
  return await repository.getLastWeekRevenue();
});
