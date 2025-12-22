import 'dart:convert';
import '../models/sale.dart';
import '../services/database_helper.dart';

class SaleRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _salesKey = 'sales';

  // Get all sales
  Future<List<Sale>> getAllSales() async {
    try {
      final jsonData = await _storage.getData(_salesKey);
      if (jsonData == null) return [];
      
      final List<dynamic> decoded = jsonDecode(jsonData);
      final sales = decoded.map((json) => Sale.fromMap(json)).toList();
      
      // Sort by date (newest first)
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sales;
    } catch (e, stackTrace) {
      print('Error getting all sales: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Save all sales
  Future<bool> _saveSales(List<Sale> sales) async {
    try {
      final jsonList = sales.map((s) => s.toMap()).toList();
      final jsonData = jsonEncode(jsonList);
      return await _storage.saveData(_salesKey, jsonData);
    } catch (e) {
      print('Error saving sales: $e');
      return false;
    }
  }

  // Get sale by ID
  Future<Sale?> getSaleById(String id) async {
    final sales = await getAllSales();
    try {
      return sales.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // Insert sale
  Future<bool> insertSale(Sale sale) async {
    try {
      final sales = await getAllSales();
      sales.add(sale);
      return await _saveSales(sales);
    } catch (e) {
      print('Error inserting sale: $e');
      return false;
    }
  }

  // Get sales by date range
  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    final sales = await getAllSales();
    return sales.where((s) {
      return s.createdAt.isAfter(start) && s.createdAt.isBefore(end);
    }).toList();
  }

  // Get today's sales
  Future<List<Sale>> getTodaysSales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getSalesByDateRange(startOfDay, endOfDay);
  }

  // Get total sales count
  Future<int> getTotalSalesCount() async {
    final sales = await getAllSales();
    return sales.length;
  }

  // Get today's sales count
  Future<int> getTodaysSalesCount() async {
    final todaysSales = await getTodaysSales();
    return todaysSales.length;
  }

  // Get total revenue
  Future<double> getTotalRevenue() async {
    final sales = await getAllSales();
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.total);
  }

  // Get today's revenue
  Future<double> getTodaysRevenue() async {
    final todaysSales = await getTodaysSales();
    return todaysSales.fold<double>(0.0, (sum, sale) => sum + sale.total);
  }

  // Get sales by payment method
  Future<List<Sale>> getSalesByPaymentMethod(String paymentMethod) async {
    final sales = await getAllSales();
    return sales.where((s) => s.paymentMethod == paymentMethod).toList();
  }

  // Get sales by employee
  Future<List<Sale>> getSalesByEmployee(String employeeId) async {
    final sales = await getAllSales();
    return sales.where((s) => s.employeeId == employeeId).toList();
  }

  // Get sales by customer
  Future<List<Sale>> getSalesByCustomer(String customerId) async {
    final sales = await getAllSales();
    return sales.where((s) => s.customerId == customerId).toList();
  }

  // Get top selling products
  Future<Map<String, int>> getTopSellingProducts({int limit = 10}) async {
    final sales = await getAllSales();
    final Map<String, int> productCounts = {};
    
    for (var sale in sales) {
      for (var item in sale.items) {
        productCounts[item.productName] = 
            (productCounts[item.productName] ?? 0) + item.quantity;
      }
    }
    
    final sortedEntries = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries.take(limit));
  }

  // Delete sale (for corrections)
  Future<bool> deleteSale(String id) async {
    final sales = await getAllSales();
    final initialLength = sales.length;
    sales.removeWhere((s) => s.id == id);
    
    if (sales.length == initialLength) return false;
    
    return await _saveSales(sales);
  }
}
