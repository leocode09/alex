import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/product_service.dart';

// Product service provider
final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService();
});

// Products list provider
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final service = ref.watch(productServiceProvider);
  return await service.getProducts();
});

// Categories provider (extracts unique categories from products)
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  final categories = products
      .where((p) => p.category != null)
      .map((p) => p.category!)
      .toSet()
      .toList();
  return categories;
});

// Filtered products provider
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

final filteredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final category = ref.watch(selectedCategoryProvider);

  return products.where((product) {
    final matchesCategory = category == 'All' || product.category == category;
    final matchesSearch = query.isEmpty || product.name.toLowerCase().contains(query);
    return matchesCategory && matchesSearch;
  }).toList();
});

// Product statistics providers
final totalProductsCountProvider = FutureProvider<int>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return products.length;
});

final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return products.where((p) => p.stock < 10).toList();
});

final totalInventoryValueProvider = FutureProvider<double>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return products.fold<double>(0.0, (sum, p) => sum + (p.price * p.stock));
});

// Product repository provider (for compatibility with existing code)
final productRepositoryProvider = Provider<ProductService>((ref) {
  return ref.watch(productServiceProvider);
});

// Individual product provider
final productProvider = FutureProvider.family<Product?, String>((ref, productId) async {
  final service = ref.watch(productServiceProvider);
  return await service.getProductById(productId);
});

// Product notifier provider
final productNotifierProvider = StateNotifierProvider<ProductNotifier, AsyncValue<List<Product>>>((ref) {
  return ProductNotifier(ref);
});

class ProductNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final Ref ref;

  ProductNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final service = ref.read(productServiceProvider);
      final products = await service.getProducts();
      state = AsyncValue.data(products);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> addProduct(Product product) async {
    try {
      final service = ref.read(productServiceProvider);
      await service.addProduct(product);
      await _loadProducts();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final service = ref.read(productServiceProvider);
      await service.updateProduct(product);
      await _loadProducts();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      final service = ref.read(productServiceProvider);
      await service.deleteProduct(id);
      await _loadProducts();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> barcodeExists(String barcode, {String? excludeId}) async {
    try {
      final products = await ref.read(productsProvider.future);
      return products.any((p) => p.barcode == barcode && p.id != excludeId);
    } catch (e) {
      return false;
    }
  }
}
