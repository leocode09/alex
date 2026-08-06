import '../models/inventory_movement.dart';
import '../services/database_helper.dart';

class InventoryMovementRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _inventoryMovementsKey = 'inventory_movements';
  static const int _maxEntries = 2000;

  // In-memory cache (static: repositories are instantiated in many places).
  // Kept sorted newest-first and capped at [_maxEntries].
  static List<InventoryMovement>? _cache;

  Future<List<InventoryMovement>> getAllMovements() async {
    final cached = _cache;
    if (cached != null) return List<InventoryMovement>.of(cached);
    try {
      final jsonData = await _storage.getData(_inventoryMovementsKey);
      if (jsonData == null) {
        _cache = <InventoryMovement>[];
        return [];
      }

      final List<dynamic> decoded = await decodeJson(jsonData);
      final movements = decoded
          .map(
              (json) => InventoryMovement.fromMap(json as Map<String, dynamic>))
          .toList();

      movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cache = movements;
      return List<InventoryMovement>.of(movements);
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

      // Cap first (insertion order), then keep the cache newest-first.
      final trimmed = existing.take(_maxEntries).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cache = trimmed;
      final jsonData =
          await encodeJson(trimmed.map((movement) => movement.toMap()).toList());
      final success =
          await _storage.saveData(_inventoryMovementsKey, jsonData);
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e, stackTrace) {
      print('Error saving inventory movements: $e');
      print('Stack trace: $stackTrace');
      _cache = null;
      return false;
    }
  }

  Future<bool> replaceAllMovements(List<InventoryMovement> movements) async {
    try {
      final sorted = [...movements]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final trimmed = sorted.take(_maxEntries).toList();
      _cache = trimmed;
      final jsonData =
          await encodeJson(trimmed.map((movement) => movement.toMap()).toList());
      final success =
          await _storage.saveData(_inventoryMovementsKey, jsonData);
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e, stackTrace) {
      print('Error replacing inventory movements: $e');
      print('Stack trace: $stackTrace');
      _cache = null;
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
