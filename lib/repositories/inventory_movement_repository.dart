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
          .map(
              (json) => InventoryMovement.fromMap(json as Map<String, dynamic>))
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
    return _applyLimit(filtered, limit: limit);
  }

  Future<List<InventoryMovement>> getVarianceMovements({
    int? limit,
    DateTime? from,
    DateTime? to,
  }) async {
    final movements = await getAllMovements();
    final filtered = movements.where((movement) {
      if (!movement.isVariance) {
        return false;
      }
      if (from != null && movement.createdAt.isBefore(from)) {
        return false;
      }
      if (to != null && movement.createdAt.isAfter(to)) {
        return false;
      }
      return true;
    }).toList();
    return _applyLimit(filtered, limit: limit);
  }

  Future<List<InventoryMovement>> getVarianceMovementsByProduct(
    String productId, {
    int? limit,
    DateTime? from,
    DateTime? to,
  }) async {
    final movements = await getVarianceMovements(from: from, to: to);
    final filtered = movements.where((m) => m.productId == productId).toList();
    return _applyLimit(filtered, limit: limit);
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

  List<InventoryMovement> _applyLimit(
    List<InventoryMovement> movements, {
    int? limit,
  }) {
    if (limit == null || limit <= 0 || movements.length <= limit) {
      return movements;
    }
    return movements.take(limit).toList();
  }
}
