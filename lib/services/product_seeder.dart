import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';

/// Sample data seeder for development and testing
class ProductSeeder {
  final ProductRepository _repository = ProductRepository();
  final _uuid = const Uuid();

  /// Seed the database with sample products
  Future<void> seedProducts() async {
    final sampleProducts = [
      Product(
        id: _uuid.v4(),
        name: 'Coca Cola',
        price: 1000,
        stock: 120,
        barcode: '12345',
        category: 'Beverages',
        supplier: 'ABC Distributors',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Bread',
        price: 800,
        stock: 30,
        barcode: '12346',
        category: 'Food',
        supplier: 'Local Bakery',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Cooking Oil',
        price: 3500,
        stock: 15,
        barcode: '12351',
        category: 'Food',
        supplier: 'Food Importers Ltd',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Eggs (12)',
        price: 2500,
        stock: 20,
        barcode: '12350',
        category: 'Food',
        supplier: 'Farm Fresh',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Milk',
        price: 1200,
        stock: 35,
        barcode: '12349',
        category: 'Beverages',
        supplier: 'Dairy Co',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Rice 1kg',
        price: 2000,
        stock: 45,
        barcode: '12348',
        category: 'Food',
        supplier: 'Grain Suppliers',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Soap',
        price: 500,
        stock: 60,
        barcode: '12352',
        category: 'Household',
        supplier: 'Hygiene Products Inc',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Sugar',
        price: 1500,
        stock: 12,
        barcode: '12347',
        category: 'Food',
        supplier: 'Sweet Supplies',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Toothpaste',
        price: 1800,
        stock: 45,
        barcode: '12353',
        category: 'Household',
        supplier: 'Dental Care Co',
      ),
      Product(
        id: _uuid.v4(),
        name: 'Water 1.5L',
        price: 600,
        stock: 80,
        barcode: '12354',
        category: 'Beverages',
        supplier: 'Pure Water Ltd',
      ),
    ];

    // Batch insert for efficiency
    await _repository.batchInsertProducts(sampleProducts);
    
    print('Successfully seeded ${sampleProducts.length} products!');
  }

  /// Clear all products and reseed
  Future<void> resetAndSeed() async {
    // Get all products
    final products = await _repository.getAllProducts();
    
    // Delete all products
    for (final product in products) {
      await _repository.deleteProduct(product.id);
    }
    
    // Seed new data
    await seedProducts();
  }

  /// Check if database needs seeding
  Future<bool> needsSeeding() async {
    final count = await _repository.getTotalProductsCount();
    return count == 0;
  }

  /// Auto-seed if database is empty
  Future<void> autoSeed() async {
    try {
      if (await needsSeeding()) {
        print('Database is empty. Seeding sample data...');
        await seedProducts();
      } else {
        print('Database already has data. Skipping seed.');
      }
    } catch (e, stackTrace) {
      print('Error in autoSeed: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
