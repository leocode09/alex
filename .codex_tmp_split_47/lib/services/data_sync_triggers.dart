import 'package:flutter/foundation.dart';

import 'lan_sync_service.dart';
import 'wifi_direct_sync_service.dart';

class DataSyncTriggers {
  static const Duration _triggerTimeout = Duration(seconds: 6);

  static Future<void> trigger({required String reason}) async {
    await Future.wait([
      _safeTrigger(
        label: 'wifi_direct',
        run: () => WifiDirectSyncService().triggerSync(reason: reason),
      ),
      _safeTrigger(
        label: 'lan',
        run: () => LanSyncService().triggerSync(reason: reason),
      ),
    ]);
  }

  static Future<void> _safeTrigger({
    required String label,
    required Future<void> Function() run,
  }) async {
    try {
      await run().timeout(_triggerTimeout);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataSyncTriggers: $label trigger failed: $e');
      }
    }
  }
}
