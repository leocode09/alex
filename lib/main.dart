import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_mode_provider.dart';
import 'routes.dart';
import 'services/admin/device_heartbeat_service.dart';
import 'services/admin/install_id_service.dart';
import 'services/admin/license_service.dart';
import 'services/admin/usage_recorder.dart';
import 'services/cloud/firebase_init.dart';
import 'services/identity_label.dart';
import 'services/update_service.dart';
import 'ui/design_system/glass/glass_background.dart';
import 'ui/themes/app_theme.dart';
import 'ui/widgets/account_watcher.dart';
import 'ui/widgets/cloud_sync_watcher.dart';
import 'ui/widgets/shop_team_watcher.dart';
import 'ui/widgets/license_watcher.dart';
import 'ui/widgets/time_tamper_watcher.dart';
import 'ui/widgets/lan_sync_watcher.dart';
import 'ui/widgets/update_banner.dart';
import 'ui/widgets/wifi_direct_sync_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init is best-effort and never blocks boot. If it fails
  // (misconfigured, offline, unsupported platform) the cloud sync UI
  // shows a "disabled" state and the app continues fully offline.
  // It runs in the background so the first frame is never gated on the
  // native Firebase handshake; dependent services await it themselves
  // (AccountService awaits FirebaseInit.ensureInitialized() before
  // deciding availability, and heartbeat/usage are chained below).
  unawaited(_bootstrapBackgroundServices());

  runApp(
    const ProviderScope(
      child: POSApp(),
    ),
  );
}

/// Boot-time background work that must not block the first frame.
///
/// Ordering inside this function mirrors the previous blocking boot
/// sequence: Firebase first, then the stable install id, then the
/// best-effort heartbeat / usage / update tasks that rely on them.
Future<void> _bootstrapBackgroundServices() async {
  await IdentityLabel.initialize();
  await FirebaseInit.ensureInitialized();

  // Assign a stable install id and begin heartbeating / usage tracking.
  // All three are best-effort and never block UI.
  await InstallIdService.ensure();
  unawaited(DeviceHeartbeatService().start());
  unawaited(UsageRecorder().start());
  unawaited(UsageRecorder().recordAppOpen());

  unawaited(UpdateService.instance.start());

  // The license stream may have kick-started before Firebase finished
  // initializing (it reads FirebaseInit.available once and emits
  // "unrestricted"); nudge it so listeners attach now that the real
  // availability is known. AccountService handles this itself by
  // awaiting FirebaseInit.ensureInitialized() in its reattach path.
  if (FirebaseInit.available) {
    unawaited(LicenseService().refresh());
  }
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
                      LanSyncWatcher(
                        child: child ?? const SizedBox.shrink(),
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: UpdateBanner(),
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
