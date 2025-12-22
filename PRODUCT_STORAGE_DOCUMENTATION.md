# Product Local Storage Documentation

## Overview
This document describes the well-structured local storage implementation for products in the POS system using SQLite and Riverpod state management.

## Architecture

### 1. Database Layer (`lib/services/database_helper.dart`)
- **Purpose**: Manages SQLite database initialization and schema
- **Database Name**: `pos_system.db`
- **Key Features**:
  - Singleton pattern for single database instance
  - Automatic database creation and versioning
  - Support for database migrations
  - Indexes for optimized queries (barcode, category)

#### Database Schema

**Products Table:**
```sql
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  stock INTEGER NOT NULL,
  barcode TEXT,
  category TEXT,
  supplier TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
```

**Indexes:**
- `idx_products_barcode` - Fast barcode lookups
- `idx_products_category` - Efficient category filtering

### 2. Repository Layer (`lib/repositories/product_repository.dart`)
- **Purpose**: Abstracts database operations and provides clean API
- **Key Methods**:
  - `getAllProducts()` - Fetch all products
  - `getProductById(id)` - Get single product
  - `getProductByBarcode(barcode)` - Find by barcode
  - `getProductsByCategory(category)` - Filter by category
  - `searchProducts(query)` - Search by name or barcode
  - `getLowStockProducts()` - Get products with low inventory
  - `insertProduct(product)` - Add new product
  - `updateProduct(product)` - Update existing product
  - `deleteProduct(id)` - Remove product
  - `updateStock(id, stock)` - Update inventory
  - `decreaseStock(id, quantity)` - For sales
  - `increaseStock(id, quantity)` - For restocking
  - `getTotalProductsCount()` - Get count of all products
  - `getTotalInventoryValue()` - Calculate total inventory value
  - `barcodeExists(barcode)` - Validate unique barcodes

### 3. State Management Layer (`lib/providers/product_provider.dart`)
- **Purpose**: Manages app state and provides reactive data
- **Framework**: Riverpod

#### Providers:

**Data Providers:**
- `productRepositoryProvider` - Repository instance
- `productsProvider` - All products list
- `productProvider(id)` - Single product by ID
- `productsByCategoryProvider(category)` - Products filtered by category
- `searchProductsProvider(query)` - Search results
- `lowStockProductsProvider` - Low inventory products
- `categoriesProvider` - List of all categories
- `totalProductsCountProvider` - Total count
- `totalInventoryValueProvider` - Total value
- `filteredProductsProvider` - Combined search + category filter

**State Providers:**
- `selectedCategoryProvider` - Currently selected category
- `searchQueryProvider` - Current search query

**Action Providers:**
- `productNotifierProvider` - CRUD operations with auto-refresh
  - `addProduct(product)` - Add new product
  - `updateProduct(product)` - Update existing
  - `deleteProduct(id)` - Delete product
  - `updateStock(id, stock)` - Update inventory
  - `barcodeExists(barcode)` - Check uniqueness

### 4. UI Layer
- **ProductCatalogPage**: Displays all products with search/filter
- **AddEditProductPage**: Form for adding/editing products
- Both pages use Riverpod consumers for reactive updates

## Data Flow

```
UI Layer (ConsumerWidget)
    ↓
Providers (Riverpod)
    ↓
Repository (ProductRepository)
    ↓
Database (DatabaseHelper + SQLite)
    ↓
Local Storage (SQLite Database File)
```

## Features

### ✅ CRUD Operations
- Create, Read, Update, Delete products
- Batch operations support
- Transaction safety

### ✅ Search & Filter
- Full-text search by name or barcode
- Category filtering
- Combined search + category filter
- Low stock alerts

### ✅ Data Validation
- Required field validation
- Unique barcode validation
- Type validation (numbers, etc.)

### ✅ Performance Optimizations
- Database indexes on frequently queried fields
- Efficient queries with proper WHERE clauses
- Lazy loading with FutureProvider
- Automatic cache invalidation

### ✅ State Management
- Reactive UI updates
- Automatic refresh after mutations
- Loading states
- Error handling

### ✅ Analytics
- Total products count
- Low stock count
- Total inventory value
- Products by category statistics

## Usage Examples

### Adding a Product
```dart
final notifier = ref.read(productNotifierProvider.notifier);
final product = Product(
  id: Uuid().v4(),
  name: 'Coca Cola',
  price: 1000,
  stock: 120,
  category: 'Beverages',
);
await notifier.addProduct(product);
```

### Searching Products
```dart
// Update search query
ref.read(searchQueryProvider.notifier).state = 'cola';

// Get filtered results
final products = ref.watch(filteredProductsProvider);
```

### Filtering by Category
```dart
ref.read(selectedCategoryProvider.notifier).state = 'Beverages';
```

### Getting Low Stock Products
```dart
final lowStockAsync = ref.watch(lowStockProductsProvider);
lowStockAsync.when(
  data: (products) => print('${products.length} products low on stock'),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error: $e'),
);
```

## Database Maintenance

### Clear All Data
```dart
await DatabaseHelper().clearAllData();
```

### Reset Database (drop and recreate)
```dart
await DatabaseHelper().resetDatabase();
```

### Close Database
```dart
await DatabaseHelper().close();
```

## Best Practices

1. **Always use providers** - Never access repository directly from UI
2. **Handle AsyncValue states** - Always handle loading/error states
3. **Invalidate providers** - After mutations, relevant providers auto-refresh
4. **Use proper validation** - Validate data before saving
5. **Check barcode uniqueness** - Before inserting/updating
6. **Use transactions** - For batch operations
7. **Optimize queries** - Use indexes and proper WHERE clauses

## Future Enhancements

- [ ] Add image storage for products
- [ ] Implement data sync with cloud
- [ ] Add product history/audit trail
- [ ] Export/Import functionality (CSV, JSON)
- [ ] Barcode scanner integration
- [ ] Product categories management
- [ ] Supplier management integration
- [ ] Advanced analytics and reports

## Dependencies

```yaml
dependencies:
  sqflite: ^2.3.3          # Local SQLite database
  flutter_riverpod: ^2.5.1 # State management
  uuid: ^4.4.0              # Unique ID generation
```

## File Structure

```
lib/
├── models/
│   └── product.dart              # Product model with toMap/fromMap
├── services/
│   └── database_helper.dart      # SQLite initialization & schema
├── repositories/
│   └── product_repository.dart   # Database operations abstraction
├── providers/
│   └── product_provider.dart     # Riverpod state management
└── ui/
    └── pages/
        └── products/
            ├── product_catalog_page.dart      # List view
            ├── add_edit_product_page.dart     # Form view
            └── product_details_page.dart      # Detail view
```

## Conclusion

This storage implementation provides:
- ✅ **Robust**: Type-safe, validated, transactional
- ✅ **Performant**: Indexed, optimized queries
- ✅ **Maintainable**: Clean architecture, separated concerns
- ✅ **Scalable**: Easy to extend with new features
- ✅ **Reactive**: Real-time UI updates with Riverpod
