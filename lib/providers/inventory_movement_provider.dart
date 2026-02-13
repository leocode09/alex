import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_movement.dart';
import '../repositories/inventory_movement_repository.dart';
import 'sync_events_provider.dart';

final inventoryMovementRepositoryProvider =
    Provider<InventoryMovementRepository>((ref) {
  return InventoryMovementRepository();
});

final inventoryMovementsProvider =
    FutureProvider<List<InventoryMovement>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(inventoryMovementRepositoryProvider);
  return repository.getAllMovements();
});

final productInventoryMovementsProvider =
    FutureProvider.family<List<InventoryMovement>, String>(
        (ref, productId) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(inventoryMovementRepositoryProvider);
  return repository.getMovementsByProduct(productId, limit: 50);
});

final inventoryVariancesProvider =
    FutureProvider<List<InventoryMovement>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(inventoryMovementRepositoryProvider);
  return repository.getVarianceMovements(limit: 200);
});

final productInventoryVariancesProvider =
    FutureProvider.family<List<InventoryMovement>, String>(
        (ref, productId) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(inventoryMovementRepositoryProvider);
  return repository.getVarianceMovementsByProduct(productId, limit: 100);
});

final inventoryVarianceStatsProvider =
    FutureProvider<InventoryVarianceStats>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(inventoryMovementRepositoryProvider);
  final movements = await repository.getVarianceMovements();
  return InventoryVarianceStats.fromMovements(movements);
});

class InventoryVarianceStats {
  final int totalLogs;
  final int matchedLogs;
  final int adjustedLogs;
  final int unitsAdded;
  final int unitsRemoved;
  final int netUnits;
  final double retailImpact;
  final double costImpact;

  const InventoryVarianceStats({
    required this.totalLogs,
    required this.matchedLogs,
    required this.adjustedLogs,
    required this.unitsAdded,
    required this.unitsRemoved,
    required this.netUnits,
    required this.retailImpact,
    required this.costImpact,
  });

  factory InventoryVarianceStats.fromMovements(
      List<InventoryMovement> movements) {
    var matchedLogs = 0;
    var unitsAdded = 0;
    var unitsRemoved = 0;
    var retailImpact = 0.0;
    var costImpact = 0.0;

    for (final movement in movements) {
      if (movement.delta == 0) {
        matchedLogs += 1;
        continue;
      }
      if (movement.delta > 0) {
        unitsAdded += movement.delta;
      } else {
        unitsRemoved += -movement.delta;
      }
      retailImpact += movement.retailValueImpact;
      costImpact += movement.costValueImpact;
    }

    final netUnits = unitsAdded - unitsRemoved;
    return InventoryVarianceStats(
      totalLogs: movements.length,
      matchedLogs: matchedLogs,
      adjustedLogs: movements.length - matchedLogs,
      unitsAdded: unitsAdded,
      unitsRemoved: unitsRemoved,
      netUnits: netUnits,
      retailImpact: retailImpact,
      costImpact: costImpact,
    );
  }
}
