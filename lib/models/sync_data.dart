import 'product.dart';
import 'category.dart';
import 'customer.dart';
import 'employee.dart';
import 'expense.dart';
import 'sale.dart';
import 'store.dart';

/// Model to hold all synchronized data
class SyncData {
  final List<Product> products;
  final List<Category> categories;
  final List<Customer> customers;
  final List<Employee> employees;
  final List<Expense> expenses;
  final List<Sale> sales;
  final List<Store> stores;
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
    DateTime? syncTimestamp,
    required this.deviceId,
    this.syncVersion = '1.0.0',
  }) : syncTimestamp = syncTimestamp ?? DateTime.now();

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'products': products.map((p) => p.toMap()).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'customers': customers.map((c) => c.toMap()).toList(),
      'employees': employees.map((e) => e.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'sales': sales.map((s) => s.toMap()).toList(),
      'stores': stores.map((s) => s.toMap()).toList(),
      'syncTimestamp': syncTimestamp.toIso8601String(),
      'deviceId': deviceId,
      'syncVersion': syncVersion,
    };
  }

  /// Create from JSON
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
        products: (json['products'] as List? ?? [])
            .map((p) => Product.fromMap(p as Map<String, dynamic>))
            .toList(),
        categories: (json['categories'] as List? ?? [])
            .map((c) => Category.fromMap(c as Map<String, dynamic>))
            .toList(),
        customers: (json['customers'] as List? ?? [])
            .map((c) => Customer.fromMap(c as Map<String, dynamic>))
            .toList(),
        employees: (json['employees'] as List? ?? [])
            .map((e) => Employee.fromMap(e as Map<String, dynamic>))
            .toList(),
        expenses: expenses,
        sales: (json['sales'] as List? ?? [])
            .map((s) => Sale.fromMap(s as Map<String, dynamic>))
            .toList(),
        stores: (json['stores'] as List? ?? [])
            .map((s) => Store.fromMap(s as Map<String, dynamic>))
            .toList(),
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

  /// Get total count of all items
  int get totalItems =>
      products.length +
      categories.length +
      customers.length +
      employees.length +
      expenses.length +
      sales.length +
      stores.length;

  /// Check if sync data is empty
  bool get isEmpty => totalItems == 0;

  /// Create an empty sync data
  factory SyncData.empty(String deviceId) {
    return SyncData(
      products: [],
      categories: [],
      customers: [],
      employees: [],
      expenses: [],
      sales: [],
      stores: [],
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
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
      deviceId: deviceId ?? this.deviceId,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}
