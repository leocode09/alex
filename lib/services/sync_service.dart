import 'dart:convert';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/sync_data.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/customer_credit_entry.dart';
import '../models/employee.dart';
import '../models/expense.dart';
import '../models/sale.dart';
import '../models/store.dart';
import '../models/inventory_movement.dart';
import '../repositories/product_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/customer_credit_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/employee_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/store_repository.dart';
import '../repositories/inventory_movement_repository.dart';
import 'shop_app_settings_service.dart';
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
  final CustomerCreditRepository _creditRepo = CustomerCreditRepository();
  final EmployeeRepository _employeeRepo = EmployeeRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final SaleRepository _saleRepo = SaleRepository();
  final StoreRepository _storeRepo = StoreRepository();
  final InventoryMovementRepository _movementRepo =
      InventoryMovementRepository();
  final ShopAppSettingsService _shopSettingsService = ShopAppSettingsService();

  static String? _cachedDeviceId;

  /// Get unique device identifier (cached — the platform-channel lookup is
  /// paid once per session, not once per sync).
  Future<String> getDeviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null) {
      return cached;
    }
    final resolved = await _resolveDeviceId();
    _cachedDeviceId = resolved;
    return resolved;
  }

  Future<String> _resolveDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String? deviceId;

      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } catch (e) {
        try {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor;
        } catch (e) {
          deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      return deviceId ?? 'unknown_device';
    } catch (e) {
      print('Error getting device ID: $e');
      return 'unknown_device';
    }
  }

  /// Export all data (including inventory movements and tombstones)
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
      final inventoryMovements = await _movementRepo.getAllMovements();
      final customerCreditEntries = await _creditRepo.getAll();

      final deletedProductIds = await _productRepo.getDeletedProductIds();
      final deletedCategoryIds = await _categoryRepo.getDeletedCategoryIds();
      final deletedCustomerIds = await _customerRepo.getDeletedCustomerIds();
      final deletedEmployeeIds = await _employeeRepo.getDeletedEmployeeIds();
      final deletedExpenseIds = await _expenseRepo.getDeletedExpenseIds();
      final deletedStoreIds = await _storeRepo.getDeletedStoreIds();
      final deletedCreditEntryIds = await _creditRepo.getDeletedIds();
      final deletedSaleIds = await _saleRepo.getDeletedSaleIds();
      final shopAppSettings = await _shopSettingsService.snapshotForSync();

      return SyncData(
        products: products,
        categories: categories,
        customers: customers,
        employees: employees,
        expenses: expenses,
        sales: sales,
        stores: stores,
        inventoryMovements: inventoryMovements,
        customerCreditEntries: customerCreditEntries,
        deletedProductIds: deletedProductIds,
        deletedCategoryIds: deletedCategoryIds,
        deletedCustomerIds: deletedCustomerIds,
        deletedEmployeeIds: deletedEmployeeIds,
        deletedExpenseIds: deletedExpenseIds,
        deletedStoreIds: deletedStoreIds,
        deletedCustomerCreditEntryIds: deletedCreditEntryIds,
        deletedSaleIds: deletedSaleIds,
        shopAppSettings: shopAppSettings.isEmpty ? null : shopAppSettings,
        deviceId: deviceId,
      );
    } catch (e) {
      print('Error exporting data: $e');
      rethrow;
    }
  }

  /// Export only records changed since [since] (plus all tombstones, which
  /// are tiny id lists). Used for delta syncs: one sale should put a few KB
  /// on the wire, not the whole dataset. Deltas import through the same
  /// merge path as full snapshots, so they are always safe to apply.
  Future<SyncData> exportChangedSince(DateTime since) async {
    try {
      final deviceId = await getDeviceId();

      bool changed(DateTime? updatedAt, DateTime? createdAt) {
        return (updatedAt != null && !updatedAt.isBefore(since)) ||
            (createdAt != null && !createdAt.isBefore(since));
      }

      final products = (await _productRepo.getAllProducts())
          .where((p) => changed(p.updatedAt, p.createdAt))
          .toList();
      final categories = (await _categoryRepo.getAllCategories())
          .where((c) => changed(c.updatedAt, null))
          .toList();
      final customers = (await _customerRepo.getAllCustomers())
          .where((c) => changed(c.updatedAt, c.joinDate))
          .toList();
      final employees = (await _employeeRepo.getAllEmployees())
          .where((e) => changed(e.updatedAt, e.joinDate))
          .toList();
      final expenses = (await _expenseRepo.getAllExpenses())
          .where((e) => changed(e.updatedAt, null))
          .toList();
      final sales = (await _saleRepo.getAllSales())
          .where((s) => changed(s.updatedAt, s.createdAt))
          .toList();
      final stores = (await _storeRepo.getAllStores())
          .where((s) => changed(s.updatedAt, s.createdAt))
          .toList();
      final inventoryMovements = (await _movementRepo.getAllMovements())
          .where((m) => changed(null, m.createdAt))
          .toList();
      final customerCreditEntries = (await _creditRepo.getAll())
          .where((e) => changed(null, e.createdAt))
          .toList();

      // Tombstones are always sent in full so deletes propagate even when
      // the deletion happened before this delta window.
      final shopAppSettings = await _shopSettingsService.snapshotForSync();
      return SyncData(
        products: products,
        categories: categories,
        customers: customers,
        employees: employees,
        expenses: expenses,
        sales: sales,
        stores: stores,
        inventoryMovements: inventoryMovements,
        customerCreditEntries: customerCreditEntries,
        deletedProductIds: await _productRepo.getDeletedProductIds(),
        deletedCategoryIds: await _categoryRepo.getDeletedCategoryIds(),
        deletedCustomerIds: await _customerRepo.getDeletedCustomerIds(),
        deletedEmployeeIds: await _employeeRepo.getDeletedEmployeeIds(),
        deletedExpenseIds: await _expenseRepo.getDeletedExpenseIds(),
        deletedStoreIds: await _storeRepo.getDeletedStoreIds(),
        deletedCustomerCreditEntryIds: await _creditRepo.getDeletedIds(),
        deletedSaleIds: await _saleRepo.getDeletedSaleIds(),
        shopAppSettings: shopAppSettings.isEmpty ? null : shopAppSettings,
        deviceId: deviceId,
      );
    } catch (e) {
      print('Error exporting delta data: $e');
      rethrow;
    }
  }

  String syncDataToJson(SyncData syncData) {
    try {
      return jsonEncode(syncData.toJson());
    } catch (e) {
      print('Error converting sync data to JSON: $e');
      rethrow;
    }
  }

  SyncData jsonToSyncData(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return SyncData.fromJson(json);
    } catch (e) {
      print('Error parsing JSON to sync data: $e');
      rethrow;
    }
  }

  Uint8List compressData(String jsonString) {
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  String decompressData(Uint8List compressedData) {
    return utf8.decode(compressedData);
  }

  /// Import and merge data with specified strategy.
  Future<SyncResult> importData(
    SyncData incomingData, {
    SyncStrategy strategy = SyncStrategy.merge,
  }) async {
    try {
      final syncResult = SyncResult();

      // Apply all tombstones up-front so incoming records for deleted ids
      // are filtered during the merge phase below.
      final tombstonesRemoved = await _applyTombstones(incomingData);

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
          syncResult.inventoryMovementsImported = await _replaceMovements(
              incomingData.inventoryMovements);
          syncResult.customerCreditEntriesImported =
              await _replaceCreditEntries(
                  incomingData.customerCreditEntries);
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
          syncResult.inventoryMovementsImported =
              await _mergeMovements(incomingData.inventoryMovements);
          syncResult.customerCreditEntriesImported =
              await _mergeCreditEntries(incomingData.customerCreditEntries);
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
          syncResult.inventoryMovementsImported =
              await _appendMovements(incomingData.inventoryMovements);
          syncResult.customerCreditEntriesImported =
              await _appendCreditEntries(incomingData.customerCreditEntries);
          break;
      }

      var settingsChanged = false;
      if (incomingData.shopAppSettings != null &&
          !incomingData.shopAppSettings!.isEmpty) {
        settingsChanged =
            await _shopSettingsService.mergeIncoming(incomingData.shopAppSettings!);
      }

      syncResult.success = true;
      syncResult.message = 'Sync completed successfully';
      // Only wake up the rest of the app (which reloads every list from disk and
      // rebuilds the UI) when this sync actually changed local data. No-op
      // re-syncs from reconnects/relays are common as device count grows, and
      // emitting on every one of them is what makes the app lag with more peers.
      if (syncResult.totalImported > 0 || tombstonesRemoved || settingsChanged) {
        SyncEventBus.instance.emit(reason: 'import');
      }
      return syncResult;
    } catch (e) {
      print('Error importing data: $e');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }

  /// Applies incoming tombstones and returns whether any local row was actually
  /// removed (so callers can avoid a full UI refresh on no-op syncs).
  Future<bool> _applyTombstones(SyncData incoming) async {
    var removed = false;
    if (incoming.deletedProductIds.isNotEmpty) {
      removed = await _productRepo
              .applyDeletedProductIds(incoming.deletedProductIds) ||
          removed;
    }
    if (incoming.deletedCategoryIds.isNotEmpty) {
      removed = await _categoryRepo
              .applyDeletedCategoryIds(incoming.deletedCategoryIds) ||
          removed;
    }
    if (incoming.deletedCustomerIds.isNotEmpty) {
      removed = await _customerRepo
              .applyDeletedCustomerIds(incoming.deletedCustomerIds) ||
          removed;
    }
    if (incoming.deletedEmployeeIds.isNotEmpty) {
      removed = await _employeeRepo
              .applyDeletedEmployeeIds(incoming.deletedEmployeeIds) ||
          removed;
    }
    if (incoming.deletedExpenseIds.isNotEmpty) {
      removed = await _expenseRepo
              .applyDeletedExpenseIds(incoming.deletedExpenseIds) ||
          removed;
    }
    if (incoming.deletedStoreIds.isNotEmpty) {
      removed =
          await _storeRepo.applyDeletedStoreIds(incoming.deletedStoreIds) ||
              removed;
    }
    if (incoming.deletedCustomerCreditEntryIds.isNotEmpty) {
      removed = await _creditRepo
              .applyDeletedIds(incoming.deletedCustomerCreditEntryIds) ||
          removed;
    }
    if (incoming.deletedSaleIds.isNotEmpty) {
      removed =
          await _saleRepo.applyDeletedSaleIds(incoming.deletedSaleIds) ||
              removed;
    }
    return removed;
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
    final watermark = await _saleRepo.getRetentionWatermark();
    final kept =
        sales.where((s) => !_isEvictedSale(s, watermark)).toList();
    await _saleRepo.replaceAllSales(kept);
    return kept.length;
  }

  /// A fully-paid sale older than the local retention watermark has been
  /// intentionally evicted from this device (the full history is kept in the
  /// cloud). Skipping it on import prevents sync from re-hydrating evicted
  /// rows. Unpaid sales are never treated as evicted so outstanding balances
  /// always come back.
  bool _isEvictedSale(Sale sale, DateTime? watermark) {
    if (watermark == null) return false;
    if (!sale.isPaidInFull) return false;
    return sale.createdAt.isBefore(watermark);
  }

  Future<int> _replaceStores(List<Store> stores) async {
    await _storeRepo.replaceAllStores(stores);
    return stores.length;
  }

  Future<int> _replaceMovements(List<InventoryMovement> movements) async {
    await _movementRepo.replaceAllMovements(movements);
    return movements.length;
  }

  Future<int> _replaceCreditEntries(
      List<CustomerCreditEntry> entries) async {
    await _creditRepo.replaceAll(entries);
    return entries.length;
  }

  Future<int> _mergeCreditEntries(
      List<CustomerCreditEntry> incoming) async {
    final deletedIds = (await _creditRepo.getDeletedIds()).toSet();
    final existing = await _creditRepo.getAll();
    final Map<String, CustomerCreditEntry> map = {
      for (final e in existing) e.id: e,
    };
    int imported = 0;
    for (final e in incoming) {
      if (deletedIds.contains(e.id)) continue;
      if (!map.containsKey(e.id)) {
        map[e.id] = e;
        imported++;
      }
    }
    if (imported > 0) {
      await _creditRepo.replaceAll(map.values.toList());
    }
    return imported;
  }

  Future<int> _appendCreditEntries(
      List<CustomerCreditEntry> incoming) async {
    final existing = await _creditRepo.getAll();
    final existingIds = existing.map((e) => e.id).toSet();
    final newItems =
        incoming.where((e) => !existingIds.contains(e.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _creditRepo.replaceAll(existing);
    }
    return newItems.length;
  }

  // Merge strategies (keep newer items based on updatedAt/createdAt)
  Future<int> _mergeProducts(List<Product> incomingProducts) async {
    final deletedIds = (await _productRepo.getDeletedProductIds()).toSet();
    final existingProducts = await _productRepo.getAllProducts();
    final Map<String, Product> productMap = {
      for (var p in existingProducts) p.id: p
    };

    int imported = 0;
    for (var incoming in incomingProducts) {
      if (deletedIds.contains(incoming.id)) continue;
      final existing = productMap[incoming.id];
      if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
        productMap[incoming.id] = incoming;
        imported++;
      }
    }

    if (imported > 0) {
      await _productRepo.replaceAllProducts(productMap.values.toList());
    }
    return imported;
  }

  Future<int> _mergeCategories(List<Category> incomingCategories) async {
    final deletedIds = (await _categoryRepo.getDeletedCategoryIds()).toSet();
    final existingCategories = await _categoryRepo.getAllCategories();
    final Map<String, Category> categoryMap = {
      for (var c in existingCategories) c.id: c
    };

    int imported = 0;
    for (var incoming in incomingCategories) {
      if (deletedIds.contains(incoming.id)) continue;
      final existing = categoryMap[incoming.id];
      if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
        categoryMap[incoming.id] = incoming;
        imported++;
      }
    }

    if (imported > 0) {
      await _categoryRepo.replaceAllCategories(categoryMap.values.toList());
    }
    return imported;
  }

  Future<int> _mergeCustomers(List<Customer> incomingCustomers) async {
    final deletedIds = (await _customerRepo.getDeletedCustomerIds()).toSet();
    final existingCustomers = await _customerRepo.getAllCustomers();
    final Map<String, Customer> customerMap = {
      for (var c in existingCustomers) c.id: c
    };

    int imported = 0;
    for (var incoming in incomingCustomers) {
      if (deletedIds.contains(incoming.id)) continue;
      final existing = customerMap[incoming.id];
      if (existing == null ||
          incoming.updatedAt.isAfter(existing.updatedAt) ||
          incoming.joinDate.isAfter(existing.joinDate)) {
        customerMap[incoming.id] = incoming;
        imported++;
      }
    }

    if (imported > 0) {
      await _customerRepo.replaceAllCustomers(customerMap.values.toList());
    }
    return imported;
  }

  Future<int> _mergeEmployees(List<Employee> incomingEmployees) async {
    final deletedIds = (await _employeeRepo.getDeletedEmployeeIds()).toSet();
    final existingEmployees = await _employeeRepo.getAllEmployees();
    final Map<String, Employee> employeeMap = {
      for (var e in existingEmployees) e.id: e
    };

    int imported = 0;
    for (var incoming in incomingEmployees) {
      if (deletedIds.contains(incoming.id)) continue;
      final existing = employeeMap[incoming.id];
      if (existing == null ||
          incoming.updatedAt.isAfter(existing.updatedAt) ||
          incoming.joinDate.isAfter(existing.joinDate)) {
        employeeMap[incoming.id] = incoming;
        imported++;
      }
    }

    if (imported > 0) {
      await _employeeRepo.replaceAllEmployees(employeeMap.values.toList());
    }
    return imported;
  }

  Future<int> _mergeExpenses(List<Expense> incomingExpenses) async {
    final deletedIds = (await _expenseRepo.getDeletedExpenseIds()).toSet();
    final existingExpenses = await _expenseRepo.getAllExpenses();
    final Map<String, Expense> expenseMap = {
      for (var e in existingExpenses) e.id: e
    };

    int imported = 0;
    for (var incoming in incomingExpenses) {
      if (deletedIds.contains(incoming.id)) continue;
      final existing = expenseMap[incoming.id];
      if (existing == null || incoming.updatedAt.isAfter(existing.updatedAt)) {
        expenseMap[incoming.id] = incoming;
        imported++;
      }
    }

    if (imported > 0) {
      await _expenseRepo.replaceAllExpenses(expenseMap.values.toList());
    }
    return imported;
  }

  Future<int> _mergeSales(List<Sale> incomingSales) async {
    final deletedIds = (await _saleRepo.getDeletedSaleIds()).toSet();
    final watermark = await _saleRepo.getRetentionWatermark();
    final existingSales = await _saleRepo.getAllSales();
    final Map<String, Sale> saleMap = {for (var s in existingSales) s.id: s};

    int imported = 0;
    for (var incoming in incomingSales) {
      if (deletedIds.contains(incoming.id)) continue;
      if (_isEvictedSale(incoming, watermark)) continue;
      final existing = saleMap[incoming.id];
      if (existing == null ||
          incoming.updatedAt.isAfter(existing.updatedAt)) {
        saleMap[incoming.id] = incoming;
        imported++;
      }
    }

    if (imported > 0) {
      await _saleRepo.replaceAllSales(saleMap.values.toList());
    }
    return imported;
  }

  Future<int> _mergeStores(List<Store> incomingStores) async {
    final deletedIds = (await _storeRepo.getDeletedStoreIds()).toSet();
    final existingStores = await _storeRepo.getAllStores();
    final Map<String, Store> storeMap = {for (var s in existingStores) s.id: s};

    int imported = 0;
    for (var incoming in incomingStores) {
      if (deletedIds.contains(incoming.id)) continue;
      final existing = storeMap[incoming.id];
      if (existing == null ||
          incoming.updatedAt.isAfter(existing.updatedAt) ||
          incoming.createdAt.isAfter(existing.createdAt)) {
        storeMap[incoming.id] = incoming;
        imported++;
      }
    }

    if (imported > 0) {
      await _storeRepo.replaceAllStores(storeMap.values.toList());
    }
    return imported;
  }

  Future<int> _mergeMovements(List<InventoryMovement> incoming) async {
    // Inventory movements are immutable; merge is id-dedupe append.
    final existing = await _movementRepo.getAllMovements();
    final Map<String, InventoryMovement> map = {
      for (var m in existing) m.id: m
    };

    int imported = 0;
    for (var m in incoming) {
      if (!map.containsKey(m.id)) {
        map[m.id] = m;
        imported++;
      }
    }

    if (imported > 0) {
      final merged = map.values.toList();
      await _movementRepo.replaceAllMovements(merged);
    }
    return imported;
  }

  // Append strategies (only add new items)
  Future<int> _appendProducts(List<Product> incomingProducts) async {
    final existing = await _productRepo.getAllProducts();
    final existingIds = existing.map((p) => p.id).toSet();
    final newItems =
        incomingProducts.where((p) => !existingIds.contains(p.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _productRepo.replaceAllProducts(existing);
    }
    return newItems.length;
  }

  Future<int> _appendCategories(List<Category> incomingCategories) async {
    final existing = await _categoryRepo.getAllCategories();
    final existingIds = existing.map((c) => c.id).toSet();
    final newItems =
        incomingCategories.where((c) => !existingIds.contains(c.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _categoryRepo.replaceAllCategories(existing);
    }
    return newItems.length;
  }

  Future<int> _appendCustomers(List<Customer> incomingCustomers) async {
    final existing = await _customerRepo.getAllCustomers();
    final existingIds = existing.map((c) => c.id).toSet();
    final newItems =
        incomingCustomers.where((c) => !existingIds.contains(c.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _customerRepo.replaceAllCustomers(existing);
    }
    return newItems.length;
  }

  Future<int> _appendEmployees(List<Employee> incomingEmployees) async {
    final existing = await _employeeRepo.getAllEmployees();
    final existingIds = existing.map((e) => e.id).toSet();
    final newItems =
        incomingEmployees.where((e) => !existingIds.contains(e.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _employeeRepo.replaceAllEmployees(existing);
    }
    return newItems.length;
  }

  Future<int> _appendExpenses(List<Expense> incomingExpenses) async {
    final existing = await _expenseRepo.getAllExpenses();
    final existingIds = existing.map((e) => e.id).toSet();
    final newItems =
        incomingExpenses.where((e) => !existingIds.contains(e.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _expenseRepo.replaceAllExpenses(existing);
    }
    return newItems.length;
  }

  Future<int> _appendSales(List<Sale> incomingSales) async {
    final watermark = await _saleRepo.getRetentionWatermark();
    final existing = await _saleRepo.getAllSales();
    final existingIds = existing.map((s) => s.id).toSet();
    final newItems = incomingSales
        .where((s) =>
            !existingIds.contains(s.id) && !_isEvictedSale(s, watermark))
        .toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _saleRepo.replaceAllSales(existing);
    }
    return newItems.length;
  }

  Future<int> _appendStores(List<Store> incomingStores) async {
    final existing = await _storeRepo.getAllStores();
    final existingIds = existing.map((s) => s.id).toSet();
    final newItems =
        incomingStores.where((s) => !existingIds.contains(s.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _storeRepo.replaceAllStores(existing);
    }
    return newItems.length;
  }

  Future<int> _appendMovements(List<InventoryMovement> incoming) async {
    final existing = await _movementRepo.getAllMovements();
    final existingIds = existing.map((m) => m.id).toSet();
    final newItems =
        incoming.where((m) => !existingIds.contains(m.id)).toList();
    if (newItems.isNotEmpty) {
      existing.addAll(newItems);
      await _movementRepo.replaceAllMovements(existing);
    }
    return newItems.length;
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
  int inventoryMovementsImported;
  int customerCreditEntriesImported;

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
    this.inventoryMovementsImported = 0,
    this.customerCreditEntriesImported = 0,
  });

  int get totalImported =>
      productsImported +
      categoriesImported +
      customersImported +
      employeesImported +
      expensesImported +
      salesImported +
      storesImported +
      inventoryMovementsImported +
      customerCreditEntriesImported;

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
      'inventoryMovementsImported': inventoryMovementsImported,
      'customerCreditEntriesImported': customerCreditEntriesImported,
      'totalImported': totalImported,
    };
  }
}
