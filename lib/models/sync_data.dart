import 'account_history_record.dart';
import 'category.dart';
import 'customer.dart';
import 'customer_credit_entry.dart';
import 'employee.dart';
import 'expense.dart';
import 'inventory_movement.dart';
import 'money_account.dart';
import 'product.dart';
import 'sale.dart';
import 'store.dart';

/// Envelope for all synced data.
///
/// Extended for cloud sync to also carry money accounts, money history,
/// inventory movements, and per-entity tombstone lists (previously only
/// products had tombstones). All new fields are optional with empty-list
/// defaults so older LAN / Wi-Fi Direct peers that send the v1 payload
/// continue to deserialize cleanly.
class SyncData {
  final List<Product> products;
  final List<Category> categories;
  final List<Customer> customers;
  final List<Employee> employees;
  final List<Expense> expenses;
  final List<Sale> sales;
  final List<Store> stores;
  final List<MoneyAccount> moneyAccounts;
  final List<AccountHistoryRecord> moneyHistory;
  final List<InventoryMovement> inventoryMovements;
  final List<CustomerCreditEntry> customerCreditEntries;

  final List<String> deletedProductIds;
  final List<String> deletedCategoryIds;
  final List<String> deletedCustomerIds;
  final List<String> deletedEmployeeIds;
  final List<String> deletedExpenseIds;
  final List<String> deletedStoreIds;
  final List<String> deletedMoneyAccountIds;
  final List<String> deletedCustomerCreditEntryIds;

  final DateTime syncTimestamp;
  final String deviceId;
  final String syncVersion;

  SyncData({
    required this.products,
    required this.categories,
    required this.customers,
    required this.employees,
    required this.expenses,
    required this.sales,
    required this.stores,
    this.moneyAccounts = const [],
    this.moneyHistory = const [],
    this.inventoryMovements = const [],
    this.customerCreditEntries = const [],
    this.deletedProductIds = const [],
    this.deletedCategoryIds = const [],
    this.deletedCustomerIds = const [],
    this.deletedEmployeeIds = const [],
    this.deletedExpenseIds = const [],
    this.deletedStoreIds = const [],
    this.deletedMoneyAccountIds = const [],
    this.deletedCustomerCreditEntryIds = const [],
    DateTime? syncTimestamp,
    required this.deviceId,
    this.syncVersion = '2.0.0',
  }) : syncTimestamp = syncTimestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'products': products.map((p) => p.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'customers': customers.map((c) => c.toMap()).toList(),
      'employees': employees.map((e) => e.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'sales': sales.map((s) => s.toMap()).toList(),
      'stores': stores.map((s) => s.toMap()).toList(),
      'moneyAccounts': moneyAccounts.map((a) => a.toMap()).toList(),
      'moneyHistory': moneyHistory.map((r) => r.toMap()).toList(),
      'inventoryMovements': inventoryMovements.map((m) => m.toMap()).toList(),
      'customerCreditEntries':
          customerCreditEntries.map((e) => e.toMap()).toList(),
      'deletedProductIds': deletedProductIds,
      'deletedCategoryIds': deletedCategoryIds,
      'deletedCustomerIds': deletedCustomerIds,
      'deletedEmployeeIds': deletedEmployeeIds,
      'deletedExpenseIds': deletedExpenseIds,
      'deletedStoreIds': deletedStoreIds,
      'deletedMoneyAccountIds': deletedMoneyAccountIds,
      'deletedCustomerCreditEntryIds': deletedCustomerCreditEntryIds,
      'syncTimestamp': syncTimestamp.toIso8601String(),
      'deviceId': deviceId,
      'syncVersion': syncVersion,
    };
  }

  factory SyncData.fromJson(Map<String, dynamic> json) {
    try {
      final rawExpenses = (json['expenses'] ?? json['expances']) as List? ?? [];
      final expenses = <Expense>[];
      for (final item in rawExpenses) {
        if (item is! Map) {
          continue;
        }
        try {
          expenses.add(Expense.fromMap(Map<String, dynamic>.from(item)));
        } catch (e) {
          print('Skipping invalid expense in sync payload: $e');
        }
      }

      return SyncData(
        products: _decodeList(
          json['products'],
          (m) => Product.fromMap(m),
        ),
        categories: _decodeList(
          json['categories'],
          (m) => Category.fromMap(m),
        ),
        customers: _decodeList(
          json['customers'],
          (m) => Customer.fromMap(m),
        ),
        employees: _decodeList(
          json['employees'],
          (m) => Employee.fromMap(m),
        ),
        expenses: expenses,
        sales: _decodeList(
          json['sales'],
          (m) => Sale.fromMap(m),
        ),
        stores: _decodeList(
          json['stores'],
          (m) => Store.fromMap(m),
        ),
        moneyAccounts: _decodeList(
          json['moneyAccounts'],
          (m) => MoneyAccount.fromMap(m),
        ),
        moneyHistory: _decodeList(
          json['moneyHistory'],
          (m) => AccountHistoryRecord.fromMap(m),
        ),
        inventoryMovements: _decodeList(
          json['inventoryMovements'],
          (m) => InventoryMovement.fromMap(m),
        ),
        customerCreditEntries: _decodeList(
          json['customerCreditEntries'],
          (m) => CustomerCreditEntry.fromMap(m),
        ),
        deletedProductIds: _decodeIds(json['deletedProductIds']),
        deletedCategoryIds: _decodeIds(json['deletedCategoryIds']),
        deletedCustomerIds: _decodeIds(json['deletedCustomerIds']),
        deletedEmployeeIds: _decodeIds(json['deletedEmployeeIds']),
        deletedExpenseIds: _decodeIds(json['deletedExpenseIds']),
        deletedStoreIds: _decodeIds(json['deletedStoreIds']),
        deletedMoneyAccountIds: _decodeIds(json['deletedMoneyAccountIds']),
        deletedCustomerCreditEntryIds:
            _decodeIds(json['deletedCustomerCreditEntryIds']),
        syncTimestamp: json['syncTimestamp'] != null
            ? DateTime.parse(json['syncTimestamp'] as String)
            : DateTime.now(),
        deviceId: json['deviceId'] as String? ?? 'unknown',
        syncVersion: json['syncVersion'] as String? ?? '1.0.0',
      );
    } catch (e) {
      print('Error parsing SyncData from JSON: $e');
      rethrow;
    }
  }

  int get totalItems =>
      products.length +
      categories.length +
      customers.length +
      employees.length +
      expenses.length +
      sales.length +
      stores.length +
      moneyAccounts.length +
      moneyHistory.length +
      inventoryMovements.length +
      customerCreditEntries.length;

  bool get isEmpty => totalItems == 0;

  factory SyncData.empty(String deviceId) {
    return SyncData(
      products: const [],
      categories: const [],
      customers: const [],
      employees: const [],
      expenses: const [],
      sales: const [],
      stores: const [],
      moneyAccounts: const [],
      moneyHistory: const [],
      inventoryMovements: const [],
      deviceId: deviceId,
    );
  }

  SyncData copyWith({
    List<Product>? products,
    List<Category>? categories,
    List<Customer>? customers,
    List<Employee>? employees,
    List<Expense>? expenses,
    List<Sale>? sales,
    List<Store>? stores,
    List<MoneyAccount>? moneyAccounts,
    List<AccountHistoryRecord>? moneyHistory,
    List<InventoryMovement>? inventoryMovements,
    List<CustomerCreditEntry>? customerCreditEntries,
    List<String>? deletedProductIds,
    List<String>? deletedCategoryIds,
    List<String>? deletedCustomerIds,
    List<String>? deletedEmployeeIds,
    List<String>? deletedExpenseIds,
    List<String>? deletedStoreIds,
    List<String>? deletedMoneyAccountIds,
    List<String>? deletedCustomerCreditEntryIds,
    DateTime? syncTimestamp,
    String? deviceId,
    String? syncVersion,
  }) {
    return SyncData(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      customers: customers ?? this.customers,
      employees: employees ?? this.employees,
      expenses: expenses ?? this.expenses,
      sales: sales ?? this.sales,
      stores: stores ?? this.stores,
      moneyAccounts: moneyAccounts ?? this.moneyAccounts,
      moneyHistory: moneyHistory ?? this.moneyHistory,
      inventoryMovements: inventoryMovements ?? this.inventoryMovements,
      customerCreditEntries:
          customerCreditEntries ?? this.customerCreditEntries,
      deletedProductIds: deletedProductIds ?? this.deletedProductIds,
      deletedCategoryIds: deletedCategoryIds ?? this.deletedCategoryIds,
      deletedCustomerIds: deletedCustomerIds ?? this.deletedCustomerIds,
      deletedEmployeeIds: deletedEmployeeIds ?? this.deletedEmployeeIds,
      deletedExpenseIds: deletedExpenseIds ?? this.deletedExpenseIds,
      deletedStoreIds: deletedStoreIds ?? this.deletedStoreIds,
      deletedMoneyAccountIds:
          deletedMoneyAccountIds ?? this.deletedMoneyAccountIds,
      deletedCustomerCreditEntryIds: deletedCustomerCreditEntryIds ??
          this.deletedCustomerCreditEntryIds,
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
      deviceId: deviceId ?? this.deviceId,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}

List<T> _decodeList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) build,
) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      out.add(build(Map<String, dynamic>.from(item)));
    } catch (_) {
      // Skip malformed entry.
    }
  }
  return out;
}

List<String> _decodeIds(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}
