import 'dart:convert';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/sync_data.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/employee.dart';
import '../models/expense.dart';
import '../models/sale.dart';
import '../models/store.dart';
import '../repositories/product_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/store_repository.dart';
import 'sync_event_bus.dart';

enum SyncStrategy {
  replace, // Replace all data with incoming data
  merge, // Merge data, keeping newer items based on timestamp
  append, // Add new items without removing existing ones
}

class SyncService {
  final ProductRepository _productRepo = ProductRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final SaleRepository _saleRepo = SaleRepository();
  final StoreRepository _storeRepo = StoreRepository();

  /// Get unique device identifier
  Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String? deviceId;

      // Try to get Android device ID
      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } catch (e) {
        // Not Android, try iOS
        try {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor;
        } catch (e) {
          // Fallback to a generated ID
          deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      return deviceId ?? 'unknown_device';
    } catch (e) {
      print('Error getting device ID: $e');
      return 'unknown_device';
    }
  }

  /// Export all data from the device
  Future<SyncData> exportAllData() async {
    try {
      final deviceId = await getDeviceId();

      final products = await _productRepo.getAllProducts();
      final categories = await _categoryRepo.getAllCategories();
      final customers = await _customerRepo.getAllCustomers();
      final employees = await _employeeRepo.getAllEmployees();
      final expenses = await _expenseRepo.getAllExpenses();
      final sales = await _saleRepo.getAllSales();
      final stores = await _storeRepo.getAllStores();

      return SyncData(
        products: products,
        categories: categories,
        customers: customers,
        employees: employees,
        expenses: expenses,
        sales: sales,
        stores: stores,
        deviceId: deviceId,
      );
    } catch (e) {
      print('Error exporting data: $e');
      rethrow;
    }
  }

  /// Convert SyncData to JSON string for QR code
  String syncDataToJson(SyncData syncData) {
    try {
      final jsonString = jsonEncode(syncData.toJson());
      // Validate size (QR codes have limits)
      if (jsonString.length > 4000) {
        print(
            'Warning: QR data size is ${jsonString.length} bytes. May be too large for QR code.');
      }
      return jsonString;
    } catch (e) {
      print('Error converting sync data to JSON: $e');
      rethrow;
    }
  }

  /// Parse JSON string to SyncData
  SyncData jsonToSyncData(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return SyncData.fromJson(json);
    } catch (e) {
      print('Error parsing JSON to sync data: $e');
      rethrow;
    }
  }

  /// Compress JSON for QR code efficiency (placeholder for future implementation)
  Uint8List compressData(String jsonString) {
    try {
      // Convert string to bytes
      // For now, just return the bytes. Could add gzip compression later if needed
      return Uint8List.fromList(utf8.encode(jsonString));
    } catch (e) {
      print('Error compressing data: $e');
      rethrow;
    }
  }

  /// Decompress data from QR code (placeholder for future implementation)
  String decompressData(Uint8List compressedData) {
    try {
      // For now, just decode the bytes. Could add gzip decompression later if needed
      return utf8.decode(compressedData);
    } catch (e) {
      print('Error decompressing data: $e');
      rethrow;
    }
  }

  /// Import and merge data with specified strategy
  Future<SyncResult> importData(
    SyncData incomingData, {
    SyncStrategy strategy = SyncStrategy.merge,
  }) async {
    try {
      final syncResult = SyncResult();

      switch (strategy) {
        case SyncStrategy.replace:
          syncResult.productsImported =
              await _replaceProducts(incomingData.products);
          syncResult.categoriesImported =
              await _replaceCategories(incomingData.categories);
          syncResult.customersImported =
              await _replaceCustomers(incomingData.customers);
          syncResult.employeesImported =
              await _replaceEmployees(incomingData.employees);
          syncResult.expensesImported =
              await _replaceExpenses(incomingData.expenses);
          syncResult.salesImported = await _replaceSales(incomingData.sales);
          syncResult.storesImported = await _replaceStores(incomingData.stores);
          break;

        case SyncStrategy.merge:
          syncResult.productsImported =
              await _mergeProducts(incomingData.products);
          syncResult.categoriesImported =
              await _mergeCategories(incomingData.categories);
          syncResult.customersImported =
              await _mergeCustomers(incomingData.customers);
          syncResult.employeesImported =
              await _mergeEmployees(incomingData.employees);
          syncResult.expensesImported =
              await _mergeExpenses(incomingData.expenses);
          syncResult.salesImported = await _mergeSales(incomingData.sales);
          syncResult.storesImported = await _mergeStores(incomingData.stores);
          break;

        case SyncStrategy.append:
          syncResult.productsImported =
              await _appendProducts(incomingData.products);
          syncResult.categoriesImported =
              await _appendCategories(incomingData.categories);
          syncResult.customersImported =
              await _appendCustomers(incomingData.customers);
          syncResult.employeesImported =
              await _appendEmployees(incomingData.employees);
          syncResult.expensesImported =
              await _appendExpenses(incomingData.expenses);
          syncResult.salesImported = await _appendSales(incomingData.sales);
          syncResult.storesImported = await _appendStores(incomingData.stores);
          break;
      }

      syncResult.success = true;
      syncResult.message = 'Sync completed successfully';
      SyncEventBus.instance.emit(reason: 'import');
      return syncResult;
    } catch (e) {
      print('Error importing data: $e');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }

  // Replace strategies
  Future<int> _replaceProducts(List<Product> products) async {
    await _productRepo.replaceAllProducts(products);
    return products.length;
  }

  Future<int> _replaceCategories(List<Category> categories) async {
    await _categoryRepo.replaceAllCategories(categories);
    return categories.length;
  }

  Future<int> _replaceCustomers(List<Customer> customers) async {
    await _customerRepo.replaceAllCustomers(customers);
    return customers.length;
  }

  Future<int> _replaceEmployees(List<Employee> employees) async {
    await _employeeRepo.replaceAllEmployees(employees);
    return employees.length;
  }

  Future<int> _replaceExpenses(List<Expense> expenses) async {
    await _expenseRepo.replaceAllExpenses(expenses);
    return expenses.length;
  }

  Future<int> _replaceSales(List<Sale> sales) async {
    await _saleRepo.replaceAllSales(sales);
    return sales.length;
  }

  Future<int> _replaceStores(List<Store> stores) async {
    await _storeRepo.replaceAllStores(stores);
    return stores.length;
  }

  // Merge strategies (keep newer items based on updatedAt/createdAt)
  Future<int> _mergeProducts(List<Product> incomingProducts) async {
    final existingProducts = await _productRepo.getAllProducts();
    final Map<String, Product> productMap = {
      for (var p in existingProducts) p.id: p
    };

    int imported = 0;
    for (var incoming in incomingProducts) {
      final existing = productMap[incoming.id];
      if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
        productMap[incoming.id] = incoming;
        imported++;
      }
    }

    await _productRepo.replaceAllProducts(productMap.values.toList());
    return imported;
  }

  Future<int> _mergeCategories(List<Category> incomingCategories) async {
    final existingCategories = await _categoryRepo.getAllCategories();
    final Map<String, Category> categoryMap = {
      for (var c in existingCategories) c.id: c
    };

    int imported = 0;
    for (var incoming in incomingCategories) {
      final existing = categoryMap[incoming.id];
      if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
        categoryMap[incoming.id] = incoming;
        imported++;
      }
    }

    await _categoryRepo.replaceAllCategories(categoryMap.values.toList());
    return imported;
  }

  Future<int> _mergeCustomers(List<Customer> incomingCustomers) async {
    final existingCustomers = await _customerRepo.getAllCustomers();
    final Map<String, Customer> customerMap = {
      for (var c in existingCustomers) c.id: c
    };

    int imported = 0;
    for (var incoming in incomingCustomers) {
      final existing = customerMap[incoming.id];
      if (existing == null || incoming.joinDate.isAfter(existing.joinDate)) {
        customerMap[incoming.id] = incoming;
        imported++;
      }
    }

    await _customerRepo.replaceAllCustomers(customerMap.values.toList());
    return imported;
  }

  Future<int> _mergeEmployees(List<Employee> incomingEmployees) async {
    final existingEmployees = await _employeeRepo.getAllEmployees();
    final Map<String, Employee> employeeMap = {
      for (var e in existingEmployees) e.id: e
    };

    int imported = 0;
    for (var incoming in incomingEmployees) {
      final existing = employeeMap[incoming.id];
      if (existing == null || incoming.joinDate.isAfter(existing.joinDate)) {
        employeeMap[incoming.id] = incoming;
        imported++;
      }
    }

    await _employeeRepo.replaceAllEmployees(employeeMap.values.toList());
    return imported;
  }

  Future<int> _mergeExpenses(List<Expense> incomingExpenses) async {
    final existingExpenses = await _expenseRepo.getAllExpenses();
    final Map<String, Expense> expenseMap = {
      for (var e in existingExpenses) e.id: e
    };

    int imported = 0;
    for (var incoming in incomingExpenses) {
      final existing = expenseMap[incoming.id];
      if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
        expenseMap[incoming.id] = incoming;
        imported++;
      }
    }

    await _expenseRepo.replaceAllExpenses(expenseMap.values.toList());
    return imported;
  }

  Future<int> _mergeSales(List<Sale> incomingSales) async {
    final existingSales = await _saleRepo.getAllSales();
    final Map<String, Sale> saleMap = {for (var s in existingSales) s.id: s};

    int imported = 0;
    for (var incoming in incomingSales) {
      if (!saleMap.containsKey(incoming.id)) {
        saleMap[incoming.id] = incoming;
        imported++;
      }
    }

    await _saleRepo.replaceAllSales(saleMap.values.toList());
    return imported;
  }

  Future<int> _mergeStores(List<Store> incomingStores) async {
    final existingStores = await _storeRepo.getAllStores();
    final Map<String, Store> storeMap = {for (var s in existingStores) s.id: s};

    int imported = 0;
    for (var incoming in incomingStores) {
      final existing = storeMap[incoming.id];
      if (existing == null || incoming.createdAt.isAfter(existing.createdAt)) {
        storeMap[incoming.id] = incoming;
        imported++;
      }
    }

    await _storeRepo.replaceAllStores(storeMap.values.toList());
    return imported;
  }

  // Append strategies (only add new items)
  Future<int> _appendProducts(List<Product> incomingProducts) async {
    final existingProducts = await _productRepo.getAllProducts();
    final existingIds = existingProducts.map((p) => p.id).toSet();

    final newProducts =
        incomingProducts.where((p) => !existingIds.contains(p.id)).toList();

    if (newProducts.isNotEmpty) {
      existingProducts.addAll(newProducts);
      await _productRepo.replaceAllProducts(existingProducts);
    }

    return newProducts.length;
  }

  Future<int> _appendCategories(List<Category> incomingCategories) async {
    final existingCategories = await _categoryRepo.getAllCategories();
    final existingIds = existingCategories.map((c) => c.id).toSet();

    final newCategories =
        incomingCategories.where((c) => !existingIds.contains(c.id)).toList();

    if (newCategories.isNotEmpty) {
      existingCategories.addAll(newCategories);
      await _categoryRepo.replaceAllCategories(existingCategories);
    }

    return newCategories.length;
  }

  Future<int> _appendCustomers(List<Customer> incomingCustomers) async {
    final existingCustomers = await _customerRepo.getAllCustomers();
    final existingIds = existingCustomers.map((c) => c.id).toSet();

    final newCustomers =
        incomingCustomers.where((c) => !existingIds.contains(c.id)).toList();

    if (newCustomers.isNotEmpty) {
      existingCustomers.addAll(newCustomers);
      await _customerRepo.replaceAllCustomers(existingCustomers);
    }

    return newCustomers.length;
  }

  Future<int> _appendEmployees(List<Employee> incomingEmployees) async {
    final existingEmployees = await _employeeRepo.getAllEmployees();
    final existingIds = existingEmployees.map((e) => e.id).toSet();

    final newEmployees =
        incomingEmployees.where((e) => !existingIds.contains(e.id)).toList();

    if (newEmployees.isNotEmpty) {
      existingEmployees.addAll(newEmployees);
      await _employeeRepo.replaceAllEmployees(existingEmployees);
    }

    return newEmployees.length;
  }

  Future<int> _appendExpenses(List<Expense> incomingExpenses) async {
    final existingExpenses = await _expenseRepo.getAllExpenses();
    final existingIds = existingExpenses.map((e) => e.id).toSet();

    final newExpenses =
        incomingExpenses.where((e) => !existingIds.contains(e.id)).toList();

    if (newExpenses.isNotEmpty) {
      existingExpenses.addAll(newExpenses);
      await _expenseRepo.replaceAllExpenses(existingExpenses);
    }

    return newExpenses.length;
  }

  Future<int> _appendSales(List<Sale> incomingSales) async {
    final existingSales = await _saleRepo.getAllSales();
    final existingIds = existingSales.map((s) => s.id).toSet();

    final newSales =
        incomingSales.where((s) => !existingIds.contains(s.id)).toList();

    if (newSales.isNotEmpty) {
      existingSales.addAll(newSales);
      await _saleRepo.replaceAllSales(existingSales);
    }

    return newSales.length;
  }

  Future<int> _appendStores(List<Store> incomingStores) async {
    final existingStores = await _storeRepo.getAllStores();
    final existingIds = existingStores.map((s) => s.id).toSet();

    final newStores =
        incomingStores.where((s) => !existingIds.contains(s.id)).toList();

    if (newStores.isNotEmpty) {
      existingStores.addAll(newStores);
      await _storeRepo.replaceAllStores(existingStores);
    }

    return newStores.length;
  }

  /// Calculate estimated size of sync data in bytes
  int calculateDataSize(SyncData syncData) {
    final jsonString = syncDataToJson(syncData);
    return utf8.encode(jsonString).length;
  }

  /// Format data size for display
  String formatDataSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}

/// Result of a sync operation
class SyncResult {
  bool success;
  String message;
  int productsImported;
  int categoriesImported;
  int customersImported;
  int employeesImported;
  int expensesImported;
  int salesImported;
  int storesImported;

  SyncResult({
    this.success = false,
    this.message = '',
    this.productsImported = 0,
    this.categoriesImported = 0,
    this.customersImported = 0,
    this.employeesImported = 0,
    this.expensesImported = 0,
    this.salesImported = 0,
    this.storesImported = 0,
  });

  int get totalImported =>
      productsImported +
      categoriesImported +
      customersImported +
      employeesImported +
      expensesImported +
      salesImported +
      storesImported;

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'productsImported': productsImported,
      'categoriesImported': categoriesImported,
      'customersImported': customersImported,
      'employeesImported': employeesImported,
      'expensesImported': expensesImported,
      'salesImported': salesImported,
      'storesImported': storesImported,
      'totalImported': totalImported,
    };
  }
}
