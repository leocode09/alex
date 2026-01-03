import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class ProductService {
  static const String _key = 'products';

  Future<List<Product>> getProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => Product.fromMap(json)).toList();
  }

  Future<void> saveProducts(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = products.map((p) => p.toMap()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }

  Future<void> addProduct(Product product) async {
    final products = await getProducts();
    products.add(product);
    await saveProducts(products);
  }

  Future<void> updateProduct(Product product) async {
    final products = await getProducts();
    final index = products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      products[index] = product;
      await saveProducts(products);
    }
  }

  Future<void> deleteProduct(String id) async {
    final products = await getProducts();
    products.removeWhere((p) => p.id == id);
    await saveProducts(products);
  }

  Future<Product?> getProductById(String id) async {
    final products = await getProducts();
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> decreaseStock(String id, int quantity) async {
    final product = await getProductById(id);
    if (product != null) {
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        price: product.price,
        stock: product.stock - quantity,
        barcode: product.barcode,
        category: product.category,
        costPrice: product.costPrice,
        supplier: product.supplier,
        createdAt: product.createdAt,
        updatedAt: DateTime.now(),
      );
      await updateProduct(updatedProduct);
    }
  }

  Future<void> increaseStock(String id, int quantity) async {
    final product = await getProductById(id);
    if (product != null) {
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        price: product.price,
        stock: product.stock + quantity,
        barcode: product.barcode,
        category: product.category,
        costPrice: product.costPrice,
        supplier: product.supplier,
        createdAt: product.createdAt,
        updatedAt: DateTime.now(),
      );
      await updateProduct(updatedProduct);
    }
  }
}
