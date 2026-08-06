import '../models/customer.dart';
import '../services/database_helper.dart';

class CustomerRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _customersKey = 'customers';
  static const String _deletedIdsKey = 'deleted_customer_ids';

  // In-memory caches (static: repositories are instantiated in many places).
  static List<Customer>? _cache;
  static List<String>? _deletedIdsCache;

  // Get all customers
  Future<List<Customer>> getAllCustomers() async {
    final cached = _cache;
    if (cached != null) return List<Customer>.of(cached);
    try {
      final jsonData = await _storage.getData(_customersKey);
      if (jsonData == null) {
        _cache = <Customer>[];
        return [];
      }

      final List<dynamic> decoded = await decodeJson(jsonData);
      final customers = decoded.map((json) => Customer.fromMap(json)).toList();

      // Sort by name
      customers.sort((a, b) => a.name.compareTo(b.name));
      _cache = customers;
      return List<Customer>.of(customers);
    } catch (e) {
      print('Error getting all customers: $e');
      return [];
    }
  }

  // Save all customers (updates the in-memory cache first so reads are
  // instantly consistent, then persists).
  Future<bool> _saveCustomers(List<Customer> customers) async {
    final snapshot = List<Customer>.of(customers)
      ..sort((a, b) => a.name.compareTo(b.name));
    _cache = snapshot;
    try {
      final jsonList = snapshot.map((c) => c.toMap()).toList();
      final jsonData = await encodeJson(jsonList);
      final success = await _storage.saveData(_customersKey, jsonData);
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e) {
      print('Error saving customers: $e');
      _cache = null;
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
    final cached = _deletedIdsCache;
    if (cached != null) return List<String>.of(cached);
    final jsonData = await _storage.getData(_deletedIdsKey);
    if (jsonData == null) {
      _deletedIdsCache = <String>[];
      return [];
    }
    try {
      final List<dynamic> decoded = await decodeJson(jsonData);
      final ids = List<String>.of(decoded.cast<String>());
      _deletedIdsCache = ids;
      return List<String>.of(ids);
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedCustomerIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedCustomerIds()).toSet();
    final before = existing.length;
    existing.addAll(ids);
    if (existing.length == before) return;
    final updated = existing.toList();
    _deletedIdsCache = updated;
    final saved =
        await _storage.saveData(_deletedIdsKey, await encodeJson(updated));
    if (!saved) _deletedIdsCache = null;
  }

  /// Returns whether any local customer was actually removed.
  Future<bool> applyDeletedCustomerIds(List<String> ids) async {
    if (ids.isEmpty) return false;
    final deletedSet = ids.toSet();
    final customers = await getAllCustomers();
    final filtered =
        customers.where((c) => !deletedSet.contains(c.id)).toList();
    final removed = filtered.length < customers.length;
    if (removed) {
      await _saveCustomers(filtered);
    }
    await addDeletedCustomerIds(ids);
    return removed;
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
