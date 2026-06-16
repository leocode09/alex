import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../helpers/license_gate.dart';
import '../../models/license_policy.dart';
import '../../repositories/sale_repository.dart';
import '../bonus_rule_service.dart';
import '../cloud/firebase_init.dart';
import '../cloud/shop_service.dart';
import '../sync_event_bus.dart';

/// Keeps the local sales ledger light by evicting old, fully-paid, and
/// confirmed-backed-up sales while the full history stays in the cloud.
///
/// Safety rules (all must hold before anything is evicted):
///   - Firebase is available AND cloud sync is licensed AND a shop is joined
///     (so there is a real cloud backup). Local-only devices keep everything.
///   - The sale is fully paid (unpaid / "Pay Later" sales are kept forever).
///   - The sale is confirmed backed up (`backed_up = 1`, set only after a
///     successful cloud push).
///   - The sale is older than `max(retentionDays, bonusWindowDays)` so the
///     dashboard's week-over-week trend and the bonus spend window keep
///     working off local data.
class LocalRetentionService {
  LocalRetentionService._internal();

  static final LocalRetentionService instance =
      LocalRetentionService._internal();

  /// Default local window for paid sales (~2 weeks). Wider than 7 days so the
  /// dashboard's "vs last week" comparison (which looks back ~13 days) still
  /// has local data.
  static const int retentionDays = 14;

  final SaleRepository _saleRepo = SaleRepository();
  final BonusRuleService _bonusRuleService = BonusRuleService();

  bool _running = false;

  /// True when this device has a real cloud backup to evict against.
  Future<bool> canEvict() async {
    if (!FirebaseInit.available) return false;
    if (!LicenseGate.isAllowed(FeatureKey.cloudSync)) return false;
    await ShopService().loadCache();
    final shopId = ShopService().cachedShopId;
    return shopId != null && shopId.isNotEmpty;
  }

  /// Evict eligible sales. Best-effort and never throws.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      if (!await canEvict()) {
        return;
      }

      final rule = await _bonusRuleService.load();
      final bonusDays = rule.enabled ? rule.windowDays : 0;
      final keepDays = math.max(retentionDays, bonusDays);

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final cutoff = startOfToday.subtract(Duration(days: keepDays));

      final evictable = await _saleRepo.getEvictableSaleIds(cutoff);
      var removed = 0;
      if (evictable.isNotEmpty) {
        removed = await _saleRepo.evictSalesLocally(evictable);
      }

      // Advance the watermark so sync won't re-import these evicted rows.
      await _saleRepo.setRetentionWatermark(cutoff);

      if (removed > 0) {
        SyncEventBus.instance.emit(reason: 'retention_evict');
        if (kDebugMode) {
          debugPrint('LocalRetention: evicted $removed old sale(s).');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalRetention: run failed -> $e');
      }
    } finally {
      _running = false;
    }
  }
}
