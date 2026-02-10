import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../services/data_sync_triggers.dart';
import 'sync_events_provider.dart';

// Repository provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

// Products list provider
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
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getProductById(id);
});

// Products by category provider
final productsByCategoryProvider =
    FutureProvider.family<List<Product>, String>((ref, category) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getProductsByCategory(category);
});

// Search products provider
final searchProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, query) async {
  ref.watch(syncEventsProvider);
  if (query.isEmpty) {
    return ref.watch(productsProvider).maybeWhen(
          data: (products) => products,
          orElse: () => [],
        );
  }
  final repository = ref.watch(productRepositoryProvider);
  return await repository.searchProducts(query);
});

// Low stock products provider
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getLowStockProducts(threshold: 20);
});

// Categories provider
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getAllCategories();
});

// Total products count provider
final totalProductsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getTotalProductsCount();
});

// Total inventory value provider
final totalInventoryValueProvider = FutureProvider<double>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getTotalInventoryValue();
});

// Products count by category provider
final productsCountByCategoryProvider =
    FutureProvider<Map<String, int>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getProductsCountByCategory();
});

// Selected category state provider
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Search query state provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered products provider (combines search and category filter)
final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  ref.watch(syncEventsProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final repository = ref.watch(productRepositoryProvider);

  if (searchQuery.isNotEmpty) {
    final searchResults = await repository.searchProducts(searchQuery);
    if (selectedCategory == null || selectedCategory.isEmpty) {
      return searchResults;
    }
    return searchResults.where((p) => p.category == selectedCategory).toList();
  }

  if (selectedCategory != null && selectedCategory.isNotEmpty) {
    return await repository.getProductsByCategory(selectedCategory);
  }

  return await repository.getAllProducts();
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
      await DataSyncTriggers.trigger(reason: 'product_added');
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
      await DataSyncTriggers.trigger(reason: 'product_updated');
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
      await DataSyncTriggers.trigger(reason: 'product_deleted');
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> updateStock(String id, int newStock) async {
    state = const AsyncValue.loading();
    try {
      final updated = await repository.updateStock(id, newStock);
      if (updated <= 0) {
        throw Exception('Failed to update stock');
      }
      state = const AsyncValue.data(null);
      _invalidateProductCaches(productId: id);
      await DataSyncTriggers.trigger(reason: 'product_stock_updated');
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> applyStockChanges(
    Map<String, int> stockChanges, {
    String syncReason = 'product_stock_updated',
  }) async {
    state = const AsyncValue.loading();
    try {
      await repository.applyStockChanges(stockChanges);
      state = const AsyncValue.data(null);
      _invalidateProductCaches();
      await DataSyncTriggers.trigger(reason: syncReason);
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
