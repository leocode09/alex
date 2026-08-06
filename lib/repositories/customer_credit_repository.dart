import '../models/customer_credit_entry.dart';
import '../services/database_helper.dart';

class CustomerCreditRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _entriesKey = 'customer_credit_entries';
  static const String _deletedIdsKey = 'deleted_customer_credit_entry_ids';

  // In-memory caches (static: repositories are instantiated in many places).
  static List<CustomerCreditEntry>? _cache;
  static List<String>? _deletedIdsCache;

  Future<List<CustomerCreditEntry>> getAll() async {
    final cached = _cache;
    if (cached != null) return List<CustomerCreditEntry>.of(cached);
    try {
      final jsonData = await _storage.getData(_entriesKey);
      if (jsonData == null) {
        _cache = <CustomerCreditEntry>[];
        return [];
      }
      final List<dynamic> decoded = await decodeJson(jsonData);
      final entries = decoded
          .map((e) => CustomerCreditEntry.fromMap(e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cache = entries;
      return List<CustomerCreditEntry>.of(entries);
    } catch (e) {
      print('Error getting credit entries: $e');
      return [];
    }
  }

  // Saves all entries (updates the in-memory cache first so reads are
  // instantly consistent, then persists).
  Future<bool> _saveAll(List<CustomerCreditEntry> entries) async {
    final snapshot = List<CustomerCreditEntry>.of(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = snapshot;
    try {
      final jsonList = snapshot.map((e) => e.toMap()).toList();
      final success =
          await _storage.saveData(_entriesKey, await encodeJson(jsonList));
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e) {
      print('Error saving credit entries: $e');
      _cache = null;
      return false;
    }
  }

  Future<List<CustomerCreditEntry>> entriesForCustomer(String customerId) async {
    final all = await getAll();
    return all.where((e) => e.customerId == customerId).toList();
  }

  Future<bool> insertEntry(CustomerCreditEntry entry) async {
    try {
      final entries = await getAll();
      entries.add(entry);
      return await _saveAll(entries);
    } catch (e) {
      print('Error inserting credit entry: $e');
      return false;
    }
  }

  Future<bool> updateEntry(CustomerCreditEntry entry) async {
    try {
      final entries = await getAll();
      final index = entries.indexWhere((e) => e.id == entry.id);
      if (index == -1) return false;
      entries[index] = entry;
      return await _saveAll(entries);
    } catch (e) {
      print('Error updating credit entry: $e');
      return false;
    }
  }

  Future<bool> deleteEntry(String id) async {
    try {
      final entries = await getAll();
      final initialLength = entries.length;
      entries.removeWhere((e) => e.id == id);
      final success = await _saveAll(entries);
      if (success && entries.length < initialLength) {
        await addDeletedIds([id]);
      }
      return success;
    } catch (e) {
      print('Error deleting credit entry: $e');
      return false;
    }
  }

  Future<List<String>> getDeletedIds() async {
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

  Future<void> addDeletedIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedIds()).toSet();
    final before = existing.length;
    existing.addAll(ids);
    if (existing.length == before) return;
    final updated = existing.toList();
    _deletedIdsCache = updated;
    final saved =
        await _storage.saveData(_deletedIdsKey, await encodeJson(updated));
    if (!saved) _deletedIdsCache = null;
  }

  /// Returns whether any local credit entry was actually removed.
  Future<bool> applyDeletedIds(List<String> ids) async {
    if (ids.isEmpty) return false;
    final deletedSet = ids.toSet();
    final entries = await getAll();
    final filtered =
        entries.where((e) => !deletedSet.contains(e.id)).toList();
    final removed = filtered.length < entries.length;
    if (removed) {
      await _saveAll(filtered);
    }
    await addDeletedIds(ids);
    return removed;
  }

  Future<bool> replaceAll(List<CustomerCreditEntry> entries) async {
    return await _saveAll(entries);
  }
}
