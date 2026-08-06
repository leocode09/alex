import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_movement.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../services/data_sync_triggers.dart';
import 'inventory_movement_provider.dart';
import 'sync_events_provider.dart';

// Repository provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

// Products list provider — the single source of truth for the product list.
// Every derived provider below computes from this one shared list instead of
// issuing its own repository read (which decodes the whole collection).
final productsProvider = FutureProvider<List<Product>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);

  try {
    return await repository.getAllProducts();
  } catch (e, stackTrace) {
    print('Error in productsProvider: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
});

// Single product provider
final productProvider =
    FutureProvider.family<Product?, String>((ref, id) async {
  final products = await ref.watch(productsProvider.future);
  for (final p in products) {
    if (p.id == id) return p;
  }
  return null;
});

// Products by category provider
final productsByCategoryProvider =
    FutureProvider.family<List<Product>, String>((ref, category) async {
  final products = await ref.watch(productsProvider.future);
  return products.where((p) => p.category == category).toList();
});

// Mirrors ProductRepository.searchProducts semantics: name or barcode
// contains the query, case-insensitive.
List<Product> _searchProducts(List<Product> products, String query) {
  final lowerQuery = query.toLowerCase();
  return products.where((p) {
    final nameMatch = p.name.toLowerCase().contains(lowerQuery);
    final barcodeMatch = p.barcode?.toLowerCase().contains(lowerQuery) ?? false;
    return nameMatch || barcodeMatch;
  }).toList();
}

// Search products provider
final searchProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, query) async {
  final products = await ref.watch(productsProvider.future);
  if (query.isEmpty) {
    return products;
  }
  return _searchProducts(products, query);
});

// Low stock products provider (threshold mirrors the repository call: <= 20,
// sorted ascending by stock)
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  final lowStock = products.where((p) => p.stock <= 20).toList()
    ..sort((a, b) => a.stock.compareTo(b.stock));
  return lowStock;
});

// Categories provider
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  final categories = products
      .where((p) => p.category != null)
      .map((p) => p.category!)
      .toSet()
      .toList()
    ..sort();
  return categories;
});

// Total products count provider
final totalProductsCountProvider = FutureProvider<int>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return products.length;
});

// Total inventory value provider
final totalInventoryValueProvider = FutureProvider<double>((ref) async {
  final products = await ref.watch(productsProvider.future);
  double total = 0;
  for (final product in products) {
    total += product.price * product.stock;
  }
  return total;
});

// Products count by category provider
final productsCountByCategoryProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  final Map<String, int> counts = {};
  for (final product in products) {
    if (product.category != null) {
      counts[product.category!] = (counts[product.category!] ?? 0) + 1;
    }
  }
  return counts;
});

// Selected category state provider
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Search query state provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered products provider (combines search and category filter)
final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final products = await ref.watch(productsProvider.future);

  if (searchQuery.isNotEmpty) {
    final searchResults = _searchProducts(products, searchQuery);
    if (selectedCategory == null || selectedCategory.isEmpty) {
      return searchResults;
    }
    return searchResults.where((p) => p.category == selectedCategory).toList();
  }

  if (selectedCategory != null && selectedCategory.isNotEmpty) {
    return products.where((p) => p.category == selectedCategory).toList();
  }

  return products;
});

// ---------------------------------------------------------------------------
// Inventory page derived providers — keep the fold/sort work out of build().
// ---------------------------------------------------------------------------

/// Sum of stock across every product.
final inventoryTotalUnitsProvider = FutureProvider<int>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return products.fold<int>(0, (sum, p) => sum + p.stock);
});

/// Products with 0 < stock <= 20, sorted by stock ascending.
final inventoryLowStockItemsProvider =
    FutureProvider<List<Product>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  final lowStock =
      products.where((p) => p.stock > 0 && p.stock <= 20).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));
  return lowStock;
});

/// Products with zero stock, sorted by name.
final inventoryOutOfStockItemsProvider =
    FutureProvider<List<Product>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  final outOfStock = products.where((p) => p.stock == 0).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return outOfStock;
});

/// Variance stats over the last 7 days of variance movements.
final recentInventoryVarianceStatsProvider =
    FutureProvider<InventoryVarianceStats>((ref) async {
  final movements = await ref.watch(inventoryVariancesProvider.future);
  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
  final recent = movements
      .where((movement) => !movement.createdAt.isBefore(sevenDaysAgo))
      .toList();
  return InventoryVarianceStats.fromMovements(recent);
});

/// The most recent variance movements (for the "Recent Variances" list).
final recentInventoryVarianceLogsProvider =
    FutureProvider<List<InventoryMovement>>((ref) async {
  final movements = await ref.watch(inventoryVariancesProvider.future);
  return movements.take(8).toList();
});

// Product operations notifier
class ProductNotifier extends StateNotifier<AsyncValue<void>> {
  final ProductRepository repository;
  final Ref ref;

  ProductNotifier(this.repository, this.ref)
      : super(const AsyncValue.data(null));

  void _invalidateProductCaches({String? productId}) {
    ref.invalidate(productsProvider);
    ref.invalidate(filteredProductsProvider);
    ref.invalidate(totalProductsCountProvider);
    ref.invalidate(totalInventoryValueProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsCountByCategoryProvider);
    ref.invalidate(lowStockProductsProvider);
    ref.invalidate(inventoryMovementsProvider);
    ref.invalidate(inventoryVariancesProvider);
    ref.invalidate(inventoryVarianceStatsProvider);
    ref.invalidate(productInventoryMovementsProvider);
    ref.invalidate(productInventoryVariancesProvider);
    if (productId != null) {
      ref.invalidate(productProvider(productId));
    }
  }

  Future<bool> addProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      final inserted = await repository.insertProduct(product);
      if (inserted <= 0) {
        throw Exception('Failed to add product');
      }
      state = const AsyncValue.data(null);
      _invalidateProductCaches(productId: product.id);
      // Sync fan-out runs in the background so mutations never stall on
      // sync socket binding (mirrors the checkout path in sales_page.dart).
      unawaited(DataSyncTriggers.trigger(reason: 'product_added'));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      final updated = await repository.updateProduct(product);
      if (updated <= 0) {
        throw Exception('Failed to update product');
      }
      state = const AsyncValue.data(null);
      _invalidateProductCaches(productId: product.id);
      unawaited(DataSyncTriggers.trigger(reason: 'product_updated'));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    state = const AsyncValue.loading();
    try {
      final deleted = await repository.deleteProduct(id);
      if (deleted <= 0) {
        throw Exception('Failed to delete product');
      }
      state = const AsyncValue.data(null);
      _invalidateProductCaches(productId: id);
      unawaited(DataSyncTriggers.trigger(reason: 'product_deleted'));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> updateStock(
    String id,
    int newStock, {
    String reason = 'stock_set',
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updated = await repository.updateStock(
        id,
        newStock,
        reason: reason,
        note: note,
      );
      if (updated <= 0) {
        throw Exception('Failed to update stock');
      }
      state = const AsyncValue.data(null);
      _invalidateProductCaches(productId: id);
      unawaited(DataSyncTriggers.trigger(reason: 'product_stock_updated'));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> applyStockChanges(
    Map<String, int> stockChanges, {
    String syncReason = 'product_stock_updated',
    String movementReason = 'stock_adjustment',
    String? referenceId,
    String? note,
    bool recordMovement = true,
    bool absorbInventoryDrift = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      await repository.applyStockChanges(
        stockChanges,
        reason: movementReason,
        referenceId: referenceId,
        note: note,
        recordMovement: recordMovement,
        absorbInventoryDrift: absorbInventoryDrift,
      );
      state = const AsyncValue.data(null);
      _invalidateProductCaches();
      unawaited(DataSyncTriggers.trigger(reason: syncReason));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> recordProductVariance(
    String productId, {
    required int countedStock,
    String reasonCode = 'count',
    String? referenceId,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      await repository.recordProductVariance(
        productId,
        countedStock: countedStock,
        reasonCode: reasonCode,
        referenceId: referenceId,
        note: note,
      );
      state = const AsyncValue.data(null);
      _invalidateProductCaches(productId: productId);
      unawaited(DataSyncTriggers.trigger(reason: 'product_variance_recorded'));
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> barcodeExists(String barcode, {String? excludeId}) async {
    try {
      return await repository.barcodeExists(barcode, excludeId: excludeId);
    } catch (e) {
      return false;
    }
  }
}

// Product notifier provider
final productNotifierProvider =
    StateNotifierProvider<ProductNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductNotifier(repository, ref);
});
