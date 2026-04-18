import 'dart:convert';
import '../models/store.dart';
import '../services/database_helper.dart';

class StoreRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _storesKey = 'stores';
  static const String _deletedIdsKey = 'deleted_store_ids';

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

  // Delete store (records tombstone for cross-device sync propagation)
  Future<bool> deleteStore(String id) async {
    try {
      final stores = await getAllStores();
      final initialLength = stores.length;
      stores.removeWhere((s) => s.id == id);
      final success = await _saveStores(stores);
      if (success && stores.length < initialLength) {
        await addDeletedStoreIds([id]);
      }
      return success;
    } catch (e) {
      print('Error deleting store: $e');
      return false;
    }
  }

  Future<List<String>> getDeletedStoreIds() async {
    final jsonData = await _storage.getData(_deletedIdsKey);
    if (jsonData == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedStoreIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedStoreIds()).toSet();
    existing.addAll(ids);
    await _storage.saveData(_deletedIdsKey, jsonEncode(existing.toList()));
  }

  Future<void> applyDeletedStoreIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final deletedSet = ids.toSet();
    final stores = await getAllStores();
    final filtered = stores.where((s) => !deletedSet.contains(s.id)).toList();
    if (filtered.length < stores.length) {
      await _saveStores(filtered);
    }
    await addDeletedStoreIds(ids);
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
