import '../models/store.dart';
import '../services/database_helper.dart';

class StoreRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _storesKey = 'stores';
  static const String _deletedIdsKey = 'deleted_store_ids';

  // In-memory caches (static: repositories are instantiated in many places).
  static List<Store>? _cache;
  static List<String>? _deletedIdsCache;

  // Get all stores
  Future<List<Store>> getAllStores() async {
    final cached = _cache;
    if (cached != null) return List<Store>.of(cached);
    try {
      final jsonData = await _storage.getData(_storesKey);
      if (jsonData == null) {
        _cache = <Store>[];
        return [];
      }

      final List<dynamic> decoded = await decodeJson(jsonData);
      final stores = decoded.map((json) => Store.fromMap(json)).toList();

      // Sort by name
      stores.sort((a, b) => a.name.compareTo(b.name));
      _cache = stores;
      return List<Store>.of(stores);
    } catch (e) {
      print('Error getting all stores: $e');
      return [];
    }
  }

  // Save all stores (updates the in-memory cache first so reads are
  // instantly consistent, then persists).
  Future<bool> _saveStores(List<Store> stores) async {
    final snapshot = List<Store>.of(stores)
      ..sort((a, b) => a.name.compareTo(b.name));
    _cache = snapshot;
    try {
      final jsonList = snapshot.map((s) => s.toMap()).toList();
      final jsonData = await encodeJson(jsonList);
      final success = await _storage.saveData(_storesKey, jsonData);
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e) {
      print('Error saving stores: $e');
      _cache = null;
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

  Future<void> addDeletedStoreIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedStoreIds()).toSet();
    final before = existing.length;
    existing.addAll(ids);
    if (existing.length == before) return;
    final updated = existing.toList();
    _deletedIdsCache = updated;
    final saved =
        await _storage.saveData(_deletedIdsKey, await encodeJson(updated));
    if (!saved) _deletedIdsCache = null;
  }

  /// Returns whether any local store was actually removed.
  Future<bool> applyDeletedStoreIds(List<String> ids) async {
    if (ids.isEmpty) return false;
    final deletedSet = ids.toSet();
    final stores = await getAllStores();
    final filtered = stores.where((s) => !deletedSet.contains(s.id)).toList();
    final removed = filtered.length < stores.length;
    if (removed) {
      await _saveStores(filtered);
    }
    await addDeletedStoreIds(ids);
    return removed;
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
