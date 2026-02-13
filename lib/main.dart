import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_mode_provider.dart';
import 'routes.dart';
import 'ui/themes/app_theme.dart';
import 'ui/widgets/time_tamper_watcher.dart';
import 'ui/widgets/wifi_direct_sync_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

    return TimeTamperWatcher(
      child: WifiDirectSyncWatcher(
        child: MaterialApp.router(
          title: 'ALEX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}
