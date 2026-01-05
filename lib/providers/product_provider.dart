import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../services/product_seeder.dart';

// Repository provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

// Products list provider with auto-seeding
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  
  try {
    // Check if we need to seed the database
    final count = await repository.getTotalProductsCount();
    if (count == 0) {
      print('Database is empty. Seeding sample data...');
      final seeder = ProductSeeder();
      await seeder.seedProducts();
    }
    
    return await repository.getAllProducts();
  } catch (e, stackTrace) {
    print('Error in productsProvider: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
});

// Single product provider
final productProvider = FutureProvider.family<Product?, String>((ref, id) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getProductById(id);
});

// Products by category provider
final productsByCategoryProvider = FutureProvider.family<List<Product>, String>((ref, category) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getProductsByCategory(category);
});

// Search products provider
final searchProductsProvider = FutureProvider.family<List<Product>, String>((ref, query) async {
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
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getLowStockProducts(threshold: 20);
});

// Categories provider
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getAllCategories();
});

// Total products count provider
final totalProductsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getTotalProductsCount();
});

// Total inventory value provider
final totalInventoryValueProvider = FutureProvider<double>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getTotalInventoryValue();
});

// Products count by category provider
final productsCountByCategoryProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getProductsCountByCategory();
});

// Selected category state provider
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// Search query state provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered products provider (combines search and category filter)
final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
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

  ProductNotifier(this.repository, this.ref) : super(const AsyncValue.data(null));

  Future<bool> addProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      await repository.insertProduct(product);
      state = const AsyncValue.data(null);
      // Invalidate products list to refresh
      ref.invalidate(productsProvider);
      ref.invalidate(filteredProductsProvider);
      ref.invalidate(totalProductsCountProvider);
      ref.invalidate(totalInventoryValueProvider);
      ref.invalidate(categoriesProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    state = const AsyncValue.loading();
    try {
      await repository.updateProduct(product);
      state = const AsyncValue.data(null);
      // Invalidate related providers
      ref.invalidate(productsProvider);
      ref.invalidate(filteredProductsProvider);
      ref.invalidate(productProvider(product.id));
      ref.invalidate(totalInventoryValueProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    state = const AsyncValue.loading();
    try {
      await repository.deleteProduct(id);
      state = const AsyncValue.data(null);
      // Invalidate related providers
      ref.invalidate(productsProvider);
      ref.invalidate(filteredProductsProvider);
      ref.invalidate(totalProductsCountProvider);
      ref.invalidate(totalInventoryValueProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> updateStock(String id, int newStock) async {
    state = const AsyncValue.loading();
    try {
      await repository.updateStock(id, newStock);
      state = const AsyncValue.data(null);
      // Invalidate related providers
      ref.invalidate(productsProvider);
      ref.invalidate(filteredProductsProvider);
      ref.invalidate(productProvider(id));
      ref.invalidate(totalInventoryValueProvider);
      ref.invalidate(lowStockProductsProvider);
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
final productNotifierProvider = StateNotifierProvider<ProductNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductNotifier(repository, ref);
});
