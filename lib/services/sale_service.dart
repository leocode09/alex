import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale.dart';

class SaleService {
  static const String _key = 'sales';

  Future<List<Sale>> getSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Sale.fromMap(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading sales: $e');
      // Clear corrupted data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      return [];
    }
  }

  Future<void> saveSales(List<Sale> sales) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = sales.map((s) => s.toMap()).toList();
    await prefs.setString(_key, json.encode(jsonList));
  }

  Future<void> addSale(Sale sale) async {
    final sales = await getSales();
    sales.add(sale);
    await saveSales(sales);
  }

  Future<double> getTotalSalesToday() async {
    final sales = await getSales();
    final today = DateTime.now();
    final todaySales = sales.where((sale) {
      return sale.timestamp.year == today.year &&
          sale.timestamp.month == today.month &&
          sale.timestamp.day == today.day;
    }).toList();

    return todaySales.fold<double>(0.0, (sum, sale) => sum + sale.total);
  }
  
  Future<void> insertSale(Sale sale) async {
    await addSale(sale);
  }

  Future<int> getSalesCountToday() async {
    final sales = await getSales();
    final today = DateTime.now();
    return sales.where((sale) {
      return sale.timestamp.year == today.year &&
          sale.timestamp.month == today.month &&
          sale.timestamp.day == today.day;
    }).length;
  }
}
