# Product Storage - Quick Reference Guide

## Quick Start

The storage system is automatically initialized when the app starts. Sample data is auto-seeded on first run.

## Common Operations

### 1. Get All Products
```dart
// In a ConsumerWidget
final productsAsync = ref.watch(productsProvider);

productsAsync.when(
  data: (products) => ListView(
    children: products.map((p) => Text(p.name)).toList(),
  ),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error: $e'),
);
```

### 2. Search Products
```dart
// Update search query
ref.read(searchQueryProvider.notifier).state = 'cola';

// Watch filtered results
final results = ref.watch(filteredProductsProvider);
```

### 3. Filter by Category
```dart
// Set category filter
ref.read(selectedCategoryProvider.notifier).state = 'Beverages';

// Get filtered products
final filtered = ref.watch(filteredProductsProvider);
```

### 4. Add New Product
```dart
final notifier = ref.read(productNotifierProvider.notifier);

final success = await notifier.addProduct(
  Product(
    id: Uuid().v4(),
    name: 'New Product',
    price: 1500,
    stock: 50,
    category: 'Food',
  ),
);

if (success) {
  // Product added successfully
  // UI will auto-refresh
}
```

### 5. Update Product
```dart
final notifier = ref.read(productNotifierProvider.notifier);
final product = existingProduct.copyWith(
  name: 'Updated Name',
  price: 2000,
);

await notifier.updateProduct(product);
// UI auto-refreshes
```

### 6. Delete Product
```dart
final notifier = ref.read(productNotifierProvider.notifier);
await notifier.deleteProduct(productId);
// Related data automatically refreshes
```

### 7. Update Stock
```dart
final notifier = ref.read(productNotifierProvider.notifier);
await notifier.updateStock(productId, 100);
// Stock updated, UI refreshes
```

### 8. Get Product by ID
```dart
final productAsync = ref.watch(productProvider(productId));

productAsync.when(
  data: (product) => product != null 
    ? Text(product.name)
    : Text('Not found'),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error'),
);
```

### 9. Check Low Stock
```dart
final lowStockAsync = ref.watch(lowStockProductsProvider);

lowStockAsync.when(
  data: (products) => Text('${products.length} low stock items'),
  loading: () => Text('Loading...'),
  error: (e, s) => Text('Error'),
);
```

### 10. Get Statistics
```dart
// Total products
final totalAsync = ref.watch(totalProductsCountProvider);

// Total value
final valueAsync = ref.watch(totalInventoryValueProvider);

// Categories list
final categoriesAsync = ref.watch(categoriesProvider);
```

## Validation

### Check Barcode Uniqueness
```dart
final notifier = ref.read(productNotifierProvider.notifier);
final exists = await notifier.barcodeExists(
  '12345',
  excludeId: currentProductId, // Optional: exclude current product in edit mode
);

if (exists) {
  // Show error: barcode already exists
}
```

## Direct Repository Access (Advanced)

For complex operations, access the repository directly:

```dart
final repository = ref.read(productRepositoryProvider);

// Custom query
final beverages = await repository.getProductsByCategory('Beverages');

// Search
final results = await repository.searchProducts('cola');

// Get by barcode
final product = await repository.getProductByBarcode('12345');

// Batch operations
await repository.batchInsertProducts(listOfProducts);
```

## Seeding Data

### Manual Seed
```dart
import 'package:pos_system/services/product_seeder.dart';

final seeder = ProductSeeder();

// Seed if empty
await seeder.autoSeed();

// Force reseed
await seeder.resetAndSeed();

// Check if needs seeding
if (await seeder.needsSeeding()) {
  await seeder.seedProducts();
}
```

## Performance Tips

1. **Use filtered providers** - Combine search and category filters
2. **Invalidate specific providers** - Only refresh what changed
3. **Batch operations** - Use `batchInsertProducts` for multiple inserts
4. **Index usage** - Queries on barcode and category are optimized
5. **Lazy loading** - Providers only fetch when watched

## Error Handling

Always handle async states:

```dart
ref.watch(productsProvider).when(
  data: (products) {
    // Success state
  },
  loading: () {
    // Loading state - show spinner
  },
  error: (error, stackTrace) {
    // Error state - show error message
    print('Error: $error');
  },
);
```

## Debugging

### Print all products
```dart
final products = await ref.read(productRepositoryProvider).getAllProducts();
for (var p in products) {
  print('${p.id}: ${p.name} - ${p.price} RWF (Stock: ${p.stock})');
}
```

### Check database stats
```dart
final repo = ref.read(productRepositoryProvider);
print('Total products: ${await repo.getTotalProductsCount()}');
print('Total value: ${await repo.getTotalInventoryValue()}');
print('Low stock: ${(await repo.getLowStockProducts()).length}');
```

### Clear database
```dart
import 'package:pos_system/services/database_helper.dart';

// Clear all data
await DatabaseHelper().clearAllData();

// Or reset completely
await DatabaseHelper().resetDatabase();
```

## Common Patterns

### Loading States
```dart
final isLoading = ref.watch(productsProvider).isLoading;
```

### Has Error
```dart
final hasError = ref.watch(productsProvider).hasError;
```

### Refresh Data
```dart
ref.invalidate(productsProvider);
// or
ref.refresh(productsProvider);
```

### Listen for Changes
```dart
ref.listen<AsyncValue<List<Product>>>(
  productsProvider,
  (previous, next) {
    next.whenData((products) {
      print('Products updated: ${products.length} items');
    });
  },
);
```
