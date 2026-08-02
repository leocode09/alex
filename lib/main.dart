import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_mode_provider.dart';
import 'routes.dart';
import 'services/admin/device_heartbeat_service.dart';
import 'services/admin/install_id_service.dart';
import 'services/admin/usage_recorder.dart';
import 'services/cloud/firebase_init.dart';
import 'ui/design_system/glass/glass_background.dart';
import 'ui/themes/app_theme.dart';
import 'ui/widgets/account_watcher.dart';
import 'ui/widgets/apk_update_watcher.dart';
import 'ui/widgets/cloud_sync_watcher.dart';
import 'ui/widgets/shop_team_watcher.dart';
import 'ui/widgets/license_watcher.dart';
import 'ui/widgets/time_tamper_watcher.dart';
import 'ui/widgets/lan_sync_watcher.dart';
import 'ui/widgets/wifi_direct_sync_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init is best-effort and never blocks boot. If it fails
  // (misconfigured, offline, unsupported platform) the cloud sync UI
  // shows a "disabled" state and the app continues fully offline.
  await FirebaseInit.ensureInitialized();

  // Assign a stable install id and begin heartbeating / usage tracking.
  // All three are best-effort and never block UI.
  await InstallIdService.ensure();
  unawaited(DeviceHeartbeatService().start());
  unawaited(UsageRecorder().start());
  unawaited(UsageRecorder().recordAppOpen());

  runApp(
    const ProviderScope(
      child: POSApp(),
    ),
  );
}

class POSApp extends ConsumerWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AccountWatcher(
      child: ShopTeamWatcher(
        child: LicenseWatcher(
          child: TimeTamperWatcher(
            child: CloudSyncWatcher(
              child: WifiDirectSyncWatcher(
                child: MaterialApp.router(
                title: 'ALEX',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                routerConfig: router,
                builder: (context, child) {
                  return Stack(
                    children: [
                      const Positioned.fill(child: GlassBackground()),
                      ApkUpdateWatcher(
                        child: LanSyncWatcher(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
