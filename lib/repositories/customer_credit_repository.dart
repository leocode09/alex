import 'dart:convert';

import '../models/customer_credit_entry.dart';
import '../services/database_helper.dart';

class CustomerCreditRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _entriesKey = 'customer_credit_entries';
  static const String _deletedIdsKey = 'deleted_customer_credit_entry_ids';

  Future<List<CustomerCreditEntry>> getAll() async {
    try {
      final jsonData = await _storage.getData(_entriesKey);
      if (jsonData == null) return [];
      final List<dynamic> decoded = jsonDecode(jsonData);
      final entries = decoded
          .map((e) => CustomerCreditEntry.fromMap(e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (e) {
      print('Error getting credit entries: $e');
      return [];
    }
  }

  Future<bool> _saveAll(List<CustomerCreditEntry> entries) async {
    try {
      final jsonList = entries.map((e) => e.toMap()).toList();
      return await _storage.saveData(_entriesKey, jsonEncode(jsonList));
    } catch (e) {
      print('Error saving credit entries: $e');
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
    final jsonData = await _storage.getData(_deletedIdsKey);
    if (jsonData == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedIds()).toSet();
    existing.addAll(ids);
    await _storage.saveData(_deletedIdsKey, jsonEncode(existing.toList()));
  }

  Future<void> applyDeletedIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final deletedSet = ids.toSet();
    final entries = await getAll();
    final filtered =
        entries.where((e) => !deletedSet.contains(e.id)).toList();
    if (filtered.length < entries.length) {
      await _saveAll(filtered);
    }
    await addDeletedIds(ids);
  }

  Future<bool> replaceAll(List<CustomerCreditEntry> entries) async {
    return await _saveAll(entries);
  }
}
