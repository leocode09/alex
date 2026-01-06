import 'dart:convert';
import '../models/store.dart';
import '../services/database_helper.dart';

class StoreRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _storesKey = 'stores';

  // Get all stores
  Future<List<Store>> getAllStores() async {
    try {
      final jsonData = await _storage.getData(_storesKey);
      if (jsonData == null) return [];
      
      final List<dynamic> decoded = jsonDecode(jsonData);
      final stores = decoded.map((json) => Store.fromMap(json)).toList();
      
      // Sort by name
      stores.sort((a, b) => a.name.compareTo(b.name));
      return stores;
    } catch (e) {
      print('Error getting all stores: $e');
      return [];
    }
  }

  // Save all stores
  Future<bool> _saveStores(List<Store> stores) async {
    try {
      final jsonList = stores.map((s) => s.toMap()).toList();
      final jsonData = jsonEncode(jsonList);
      return await _storage.saveData(_storesKey, jsonData);
    } catch (e) {
      print('Error saving stores: $e');
      return false;
    }
  }

  // Get store by ID
  Future<Store?> getStoreById(String id) async {
    final stores = await getAllStores();
    try {
      return stores.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // Insert store
  Future<bool> insertStore(Store store) async {
    try {
      final stores = await getAllStores();
      stores.add(store);
      return await _saveStores(stores);
    } catch (e) {
      print('Error inserting store: $e');
      return false;
    }
  }

  // Update store
  Future<bool> updateStore(Store updatedStore) async {
    try {
      final stores = await getAllStores();
      final index = stores.indexWhere((s) => s.id == updatedStore.id);
      if (index != -1) {
        stores[index] = updatedStore;
        return await _saveStores(stores);
      }
      return false;
    } catch (e) {
      print('Error updating store: $e');
      return false;
    }
  }

  // Delete store
  Future<bool> deleteStore(String id) async {
    try {
      final stores = await getAllStores();
      stores.removeWhere((s) => s.id == id);
      return await _saveStores(stores);
    } catch (e) {
      print('Error deleting store: $e');
      return false;
    }
  }

  // Replace all stores (for sync)
  Future<bool> replaceAllStores(List<Store> stores) async {
    return await _saveStores(stores);
  }

  // Get active stores
  Future<List<Store>> getActiveStores() async {
    final stores = await getAllStores();
    return stores.where((s) => s.isActive).toList();
  }
}
