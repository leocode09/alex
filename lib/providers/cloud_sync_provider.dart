import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cloud/cloud_sync_service.dart';
import '../services/cloud/shop_service.dart';

final cloudSyncServiceProvider = Provider<CloudSyncService>(
  (ref) => CloudSyncService(),
);

final shopServiceProvider = Provider<ShopService>(
  (ref) => ShopService(),
);
