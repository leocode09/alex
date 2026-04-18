import 'dart:convert';
import '../models/customer.dart';
import '../services/database_helper.dart';

class CustomerRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _customersKey = 'customers';
  static const String _deletedIdsKey = 'deleted_customer_ids';

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

  // Delete customer (records tombstone for cross-device sync propagation)
  Future<bool> deleteCustomer(String id) async {
    try {
      final customers = await getAllCustomers();
      final initialLength = customers.length;
      customers.removeWhere((c) => c.id == id);
      final success = await _saveCustomers(customers);
      if (success && customers.length < initialLength) {
        await addDeletedCustomerIds([id]);
      }
      return success;
    } catch (e) {
      print('Error deleting customer: $e');
      return false;
    }
  }

  Future<List<String>> getDeletedCustomerIds() async {
    final jsonData = await _storage.getData(_deletedIdsKey);
    if (jsonData == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedCustomerIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedCustomerIds()).toSet();
    existing.addAll(ids);
    await _storage.saveData(_deletedIdsKey, jsonEncode(existing.toList()));
  }

  Future<void> applyDeletedCustomerIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final deletedSet = ids.toSet();
    final customers = await getAllCustomers();
    final filtered =
        customers.where((c) => !deletedSet.contains(c.id)).toList();
    if (filtered.length < customers.length) {
      await _saveCustomers(filtered);
    }
    await addDeletedCustomerIds(ids);
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
