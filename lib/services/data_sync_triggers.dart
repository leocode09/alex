import 'lan_sync_service.dart';
import 'wifi_direct_sync_service.dart';

class DataSyncTriggers {
  static Future<void> trigger({required String reason}) async {
    await WifiDirectSyncService().triggerSync(reason: reason);
    await LanSyncService().triggerSync(reason: reason);
  }
}
