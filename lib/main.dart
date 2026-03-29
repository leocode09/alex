import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'providers/theme_mode_provider.dart';
import 'routes.dart';
import 'ui/themes/app_theme.dart';
import 'ui/widgets/time_tamper_watcher.dart';
import 'ui/widgets/lan_sync_watcher.dart';
import 'ui/widgets/wifi_direct_sync_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(_maybeDownloadShorebirdPatch());

  runApp(
    const ProviderScope(
      child: POSApp(),
    ),
  );
}

/// Checks for a Shorebird patch and downloads it when outdated.
/// Patches apply on the next app start (release builds from `shorebird release` only).
Future<void> _maybeDownloadShorebirdPatch() async {
  if (kIsWeb) {
    return;
  }
  final updater = ShorebirdUpdater();
  if (!updater.isAvailable) {
    return;
  }
  try {
    final current = await updater.readCurrentPatch();
    if (kDebugMode) {
      debugPrint(
        'Shorebird: current patch ${current?.number ?? "none"}',
      );
    }
    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.outdated) {
      await updater.update();
    }
  } on Object catch (e, st) {
    debugPrint('Shorebird: update check failed: $e\n$st');
  }
}

class POSApp extends ConsumerWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return TimeTamperWatcher(
      child: WifiDirectSyncWatcher(
        child: MaterialApp.router(
          title: 'ALEX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: router,
          builder: (context, child) {
            return LanSyncWatcher(child: child ?? const SizedBox.shrink());
          },
        ),
      ),
    );
  }
}
