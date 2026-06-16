import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../helpers/license_gate.dart';
import '../../models/license_policy.dart';
import '../../models/sale.dart';
import 'cloud_entity_mapper.dart';
import 'firebase_init.dart';
import 'firestore_paths.dart';
import 'shop_service.dart';

/// On-demand reader for historical sales that have been evicted from local
/// storage but still live in the cloud backup.
///
/// Reports and the receipts search use this to surface data older than the
/// local retention window. It is read-only: returned sales are for display
/// only and are never written back into local storage (so they don't get
/// re-synced or re-evicted).
///
/// Queries range over the existing `createdAt` ISO-8601 string field, which
/// every sale document already carries (ISO-8601 sorts chronologically), so
/// no schema change or composite index is required — Firestore's automatic
/// single-field index on `createdAt` is sufficient.
class CloudHistoryService {
  CloudHistoryService._internal();

  static final CloudHistoryService instance = CloudHistoryService._internal();

  final ShopService _shopService = ShopService();

  /// Whether on-demand cloud history is usable on this device right now.
  Future<bool> isAvailable() async {
    if (!FirebaseInit.available) return false;
    if (!LicenseGate.isAllowed(FeatureKey.cloudSync)) return false;
    await _shopService.loadCache();
    final shopId = _shopService.cachedShopId;
    return shopId != null && shopId.isNotEmpty;
  }

  /// Fetch sales whose `createdAt` falls within [start, end] (inclusive)
  /// from the cloud. Returns an empty list when cloud history is unavailable.
  Future<List<Sale>> fetchSalesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      if (!await isAvailable()) return const [];
      final shopId = _shopService.cachedShopId!;
      await _shopService.ensureAuth();

      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.shopsCollection)
          .doc(shopId)
          .collection(FirestorePaths.salesSubcollection)
          .where('createdAt',
              isGreaterThanOrEqualTo: start.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      final sales = <Sale>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (CloudEntityMapper.isDeleted(data)) continue;
        final sale = CloudEntityMapper.saleFromDoc(data);
        if (sale != null) sales.add(sale);
      }
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sales;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CloudHistoryService.fetchSalesByDateRange failed -> $e');
      }
      return const [];
    }
  }
}
