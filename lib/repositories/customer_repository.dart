import 'dart:convert';
import '../models/customer.dart';
import '../services/database_helper.dart';

class CustomerRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _customersKey = 'customers';

  // Get all customers
  Future<List<Customer>> getAllCustomers() async {
    try {
      final jsonData = await _storage.getData(_customersKey);
      if (jsonData == null) return [];

      final List<dynamic> decoded = jsonDecode(jsonData);
      final customers = decoded.map((json) => Customer.fromMap(json)).toList();

      // Sort by name
      customers.sort((a, b) => a.name.compareTo(b.name));
      return customers;
    } catch (e) {
      print('Error getting all customers: $e');
      return [];
    }
  }

  // Save all customers
  Future<bool> _saveCustomers(List<Customer> customers) async {
    try {
      final jsonList = customers.map((c) => c.toMap()).toList();
      final jsonData = jsonEncode(jsonList);
      return await _storage.saveData(_customersKey, jsonData);
    } catch (e) {
      print('Error saving customers: $e');
      return false;
    }
  }

  // Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    final customers = await getAllCustomers();
    try {
      return customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Insert customer
  Future<bool> insertCustomer(Customer customer) async {
    try {
      final customers = await getAllCustomers();
      customers.add(customer);
      return await _saveCustomers(customers);
    } catch (e) {
      print('Error inserting customer: $e');
      return false;
    }
  }

  // Update customer
  Future<bool> updateCustomer(Customer updatedCustomer) async {
    try {
      final customers = await getAllCustomers();
      final index = customers.indexWhere((c) => c.id == updatedCustomer.id);
      if (index != -1) {
        customers[index] = updatedCustomer;
        return await _saveCustomers(customers);
      }
      return false;
    } catch (e) {
      print('Error updating customer: $e');
      return false;
    }
  }

  // Delete customer
  Future<bool> deleteCustomer(String id) async {
    try {
      final customers = await getAllCustomers();
      customers.removeWhere((c) => c.id == id);
      return await _saveCustomers(customers);
    } catch (e) {
      print('Error deleting customer: $e');
      return false;
    }
  }

  // Replace all customers (for sync)
  Future<bool> replaceAllCustomers(List<Customer> customers) async {
    return await _saveCustomers(customers);
  }

  // Search customers
  Future<List<Customer>> searchCustomers(String query) async {
    final customers = await getAllCustomers();
    final lowerQuery = query.toLowerCase();
    return customers.where((c) {
      final nameMatch = c.name.toLowerCase().contains(lowerQuery);
      final phoneMatch = c.phone?.toLowerCase().contains(lowerQuery) ?? false;
      final emailMatch = c.email?.toLowerCase().contains(lowerQuery) ?? false;
      return nameMatch || phoneMatch || emailMatch;
    }).toList();
  }
}
