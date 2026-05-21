import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_state.dart';
import '../../providers/account_provider.dart';
import '../../services/cloud/cloud_sync_service.dart';
import '../../services/pin_service.dart';
import '../../services/shop_app_settings_service.dart';
import '../../services/sync_event_bus.dart';

/// Keeps shop-wide data (catalog, settings, PIN) in sync when a device
/// becomes an approved member of a business team.
class ShopTeamWatcher extends ConsumerStatefulWidget {
  const ShopTeamWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShopTeamWatcher> createState() => _ShopTeamWatcherState();
}

class _ShopTeamWatcherState extends ConsumerState<ShopTeamWatcher> {
  AccountStage? _lastStage;
  String? _lastShopId;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AccountState>>(accountStateProvider, (_, next) {
      final account = next.valueOrNull;
      if (account == null) {
        return;
      }

      final becameApproved = _lastStage != null &&
          _lastStage != AccountStage.approved &&
          account.stage == AccountStage.approved;
      final shopChanged =
          account.shopId != null && account.shopId != _lastShopId;

      if (account.allowsAppAccess &&
          account.shopId != null &&
          (becameApproved || shopChanged)) {
        unawaited(_bootstrapTeamMember(account));
      }

      if (!account.allowsAppAccess && _lastStage == AccountStage.approved) {
        unawaited(CloudSyncService().refresh());
      }

      _lastStage = account.stage;
      _lastShopId = account.shopId;
    });

    return widget.child;
  }

  Future<void> _bootstrapTeamMember(AccountState account) async {
    final shopId = account.shopId;
    if (shopId == null || shopId.isEmpty) {
      return;
    }

    await PinService().ensurePinReady(account: account);
    await ShopAppSettingsService().pullFromCloud(shopId);
    SyncEventBus.instance.emit(reason: 'team_bootstrap');
    await CloudSyncService().refresh();
  }
}
