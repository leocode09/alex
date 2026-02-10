import 'dart:convert';
import '../models/inventory_movement.dart';
import '../services/database_helper.dart';

class InventoryMovementRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _inventoryMovementsKey = 'inventory_movements';
  static const int _maxEntries = 2000;

  Future<List<InventoryMovement>> getAllMovements() async {
    try {
      final jsonData = await _storage.getData(_inventoryMovementsKey);
      if (jsonData == null) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonData);
      final movements = decoded
          .map((json) => InventoryMovement.fromMap(json as Map<String, dynamic>))
          .toList();

      movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return movements;
    } catch (e, stackTrace) {
      print('Error getting inventory movements: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<InventoryMovement>> getMovementsByProduct(
    String productId, {
    int? limit,
  }) async {
    final movements = await getAllMovements();
    final filtered = movements.where((m) => m.productId == productId).toList();
    if (limit == null || limit <= 0 || filtered.length <= limit) {
      return filtered;
    }
    return filtered.take(limit).toList();
  }

  Future<bool> addMovement(InventoryMovement movement) async {
    return addMovements([movement]);
  }

  Future<bool> addMovements(List<InventoryMovement> newMovements) async {
    if (newMovements.isEmpty) {
      return true;
    }

    try {
      final existing = await getAllMovements();
      existing.insertAll(0, newMovements);

      final trimmed = existing.take(_maxEntries).toList();
      final jsonData =
          jsonEncode(trimmed.map((movement) => movement.toMap()).toList());
      return await _storage.saveData(_inventoryMovementsKey, jsonData);
    } catch (e, stackTrace) {
      print('Error saving inventory movements: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> replaceAllMovements(List<InventoryMovement> movements) async {
    try {
      final sorted = [...movements]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final trimmed = sorted.take(_maxEntries).toList();
      final jsonData =
          jsonEncode(trimmed.map((movement) => movement.toMap()).toList());
      return await _storage.saveData(_inventoryMovementsKey, jsonData);
    } catch (e, stackTrace) {
      print('Error replacing inventory movements: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
}
