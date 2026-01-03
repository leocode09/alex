import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';

// Sale service provider
final saleServiceProvider = Provider<SaleService>((ref) {
  return SaleService();
});

// Sales list provider
final salesProvider = FutureProvider<List<Sale>>((ref) async {
  final service = ref.watch(saleServiceProvider);
  return await service.getSales();
});

// Today's sales count
final todaysSalesCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(saleServiceProvider);
  return await service.getSalesCountToday();
});

// Today's revenue
final todaysRevenueProvider = FutureProvider<double>((ref) async {
  final service = ref.watch(saleServiceProvider);
  return await service.getTotalSalesToday();
});

// Sale repository provider (for compatibility)
final saleRepositoryProvider = Provider<SaleService>((ref) {
  return ref.watch(saleServiceProvider);
});
