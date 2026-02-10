import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_movement.dart';
import '../repositories/inventory_movement_repository.dart';
import 'sync_events_provider.dart';

final inventoryMovementRepositoryProvider =
    Provider<InventoryMovementRepository>((ref) {
  return InventoryMovementRepository();
});

final inventoryMovementsProvider = FutureProvider<List<InventoryMovement>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(inventoryMovementRepositoryProvider);
  return repository.getAllMovements();
});

final productInventoryMovementsProvider =
    FutureProvider.family<List<InventoryMovement>, String>((ref, productId) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(inventoryMovementRepositoryProvider);
  return repository.getMovementsByProduct(productId, limit: 50);
});
