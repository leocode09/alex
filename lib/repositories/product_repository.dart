import 'dart:convert';
import '../models/product.dart';
import '../services/database_helper.dart';

class StockOperationException implements Exception {
  final String message;

  const StockOperationException(this.message);

  @override
  String toString() => message;
}

class ProductRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _productsKey = 'products';

  // Get all products
  Future<List<Product>> getAllProducts() async {
    try {
      final jsonData = await _storage.getData(_productsKey);
      if (jsonData == null) return [];
      
      final List<dynamic> decoded = jsonDecode(jsonData);
      final products = decoded.map((json) => Product.fromMap(json)).toList();
      
      // Sort by name
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    } catch (e, stackTrace) {
      print('Error getting all products: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Save all products
  Future<bool> _saveProducts(List<Product> products) async {
    try {
      final jsonList = products.map((p) => p.toMap()).toList();
      final jsonData = jsonEncode(jsonList);
      return await _storage.saveData(_productsKey, jsonData);
    } catch (e) {
      print('Error saving products: $e');
      return false;
    }
  }

  // Get product by ID
  Future<Product?> getProductById(String id) async {
    final products = await getAllProducts();
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get product by barcode
  Future<Product?> getProductByBarcode(String barcode) async {
    final products = await getAllProducts();
    try {
      return products.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  // Get products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    final products = await getAllProducts();
    return products.where((p) => p.category == category).toList();
  }

  // Search products by name or barcode
  Future<List<Product>> searchProducts(String query) async {
    final products = await getAllProducts();
    final lowerQuery = query.toLowerCase();
    return products.where((p) {
      final nameMatch = p.name.toLowerCase().contains(lowerQuery);
      final barcodeMatch = p.barcode?.toLowerCase().contains(lowerQuery) ?? false;
      return nameMatch || barcodeMatch;
    }).toList();
  }

  // Get low stock products
  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    final products = await getAllProducts();
    final lowStock = products.where((p) => p.stock <= threshold).toList();
    lowStock.sort((a, b) => a.stock.compareTo(b.stock));
    return lowStock;
  }

  // Get all categories
  Future<List<String>> getAllCategories() async {
    final products = await getAllProducts();
    final categories = products
        .where((p) => p.category != null)
        .map((p) => p.category!)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  // Insert product
  Future<int> insertProduct(Product product) async {
    final products = await getAllProducts();
    products.add(product);
    final success = await _saveProducts(products);
    return success ? 1 : 0;
  }

  // Update product
  Future<int> updateProduct(Product product) async {
    final products = await getAllProducts();
    final index = products.indexWhere((p) => p.id == product.id);
    
    if (index == -1) return 0;
    
    // Update the updatedAt timestamp
    final updatedProduct = product.copyWith(
      updatedAt: DateTime.now(),
    );
    
    products[index] = updatedProduct;
    final success = await _saveProducts(products);
    return success ? 1 : 0;
  }

  // Delete product
  Future<int> deleteProduct(String id) async {
    final products = await getAllProducts();
    final initialLength = products.length;
    products.removeWhere((p) => p.id == id);
    
    if (products.length == initialLength) return 0;
    
    final success = await _saveProducts(products);
    return success ? 1 : 0;
  }

  // Update stock
  Future<int> updateStock(String id, int newStock) async {
    if (newStock < 0) {
      return 0;
    }

    final product = await getProductById(id);
    if (product == null) {
      return 0;
    }

    final delta = newStock - product.stock;
    if (delta == 0) {
      return 1;
    }

    try {
      await applyStockChanges({id: delta});
      return 1;
    } catch (e) {
      print('Error updating stock for $id: $e');
      return 0;
    }
  }

  // Apply multiple stock changes in one validated write.
  // Positive value increases stock, negative value decreases stock.
  Future<void> applyStockChanges(Map<String, int> stockChanges) async {
    final changes = <String, int>{};
    stockChanges.forEach((productId, delta) {
      if (delta == 0) {
        return;
      }
      changes[productId] = (changes[productId] ?? 0) + delta;
    });

    changes.removeWhere((_, delta) => delta == 0);
    if (changes.isEmpty) {
      return;
    }

    final products = await getAllProducts();
    final productsById = {for (final product in products) product.id: product};
    final updatedProducts = Map<String, Product>.from(productsById);
    final now = DateTime.now();

    for (final entry in changes.entries) {
      final productId = entry.key;
      final delta = entry.value;
      final existing = updatedProducts[productId];

      if (existing == null) {
        throw StockOperationException('Product not found: $productId');
      }

      final newStock = existing.stock + delta;
      if (newStock < 0) {
        throw StockOperationException(
          'Insufficient stock for ${existing.name}. Available: ${existing.stock}, requested: ${-delta}.',
        );
      }

      updatedProducts[productId] = existing.copyWith(
        stock: newStock,
        updatedAt: now,
      );
    }

    final productList = updatedProducts.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final success = await _saveProducts(productList);
    if (!success) {
      throw const StockOperationException('Failed to save stock changes.');
    }
  }

  // Decrease stock (for sales)
  Future<bool> decreaseStock(String id, int quantity) async {
    if (quantity <= 0) {
      return false;
    }

    try {
      await applyStockChanges({id: -quantity});
      return true;
    } catch (e) {
      print('Error decreasing stock for $id: $e');
      return false;
    }
  }

  // Increase stock (for restocking)
  Future<bool> increaseStock(String id, int quantity) async {
    if (quantity <= 0) {
      return false;
    }

    try {
      await applyStockChanges({id: quantity});
      return true;
    } catch (e) {
      print('Error increasing stock for $id: $e');
      return false;
    }
  }

  // Get total products count
  Future<int> getTotalProductsCount() async {
    final products = await getAllProducts();
    return products.length;
  }

  // Get total inventory value
  Future<double> getTotalInventoryValue() async {
    final products = await getAllProducts();
    double total = 0;
    for (var product in products) {
      total += product.price * product.stock;
    }
    return total;
  }

  // Get products count by category
  Future<Map<String, int>> getProductsCountByCategory() async {
    final products = await getAllProducts();
    final Map<String, int> counts = {};
    
    for (var product in products) {
      if (product.category != null) {
        counts[product.category!] = (counts[product.category!] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  // Batch insert products (useful for import)
  Future<void> batchInsertProducts(List<Product> products) async {
    final existingProducts = await getAllProducts();
    existingProducts.addAll(products);
    await _saveProducts(existingProducts);
  }

  // Check if barcode exists (for validation)
  Future<bool> barcodeExists(String barcode, {String? excludeId}) async {
    final products = await getAllProducts();
    return products.any((p) => 
      p.barcode == barcode && (excludeId == null || p.id != excludeId)
    );
  }

  // Replace all products (for sync)
  Future<bool> replaceAllProducts(List<Product> products) async {
    return await _saveProducts(products);
  }
}
