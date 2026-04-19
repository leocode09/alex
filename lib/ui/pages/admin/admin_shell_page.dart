import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_auth_provider.dart';
import '../../design_system/app_tokens.dart';
import 'admin_dashboard_page.dart';
import 'admin_devices_page.dart';
import 'admin_shops_page.dart';

/// Sections of the admin panel. The shell renders one at a time and
/// switches via the bottom-nav / tab bar.
enum AdminShellSection { dashboard, shops, devices }

class AdminShellPage extends ConsumerStatefulWidget {
  final AdminShellSection section;

  const AdminShellPage({super.key, required this.section});

  @override
  ConsumerState<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends ConsumerState<AdminShellPage> {
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(adminUidProvider);
    if (uid == null) {
      // Not signed in — redirect once the widget is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/admin-login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final index = widget.section.index;
    Widget body;
    String title;
    switch (widget.section) {
      case AdminShellSection.dashboard:
        title = 'Admin dashboard';
        body = const AdminDashboardPage();
        break;
      case AdminShellSection.shops:
        title = 'Shops';
        body = const AdminShopsPage();
        break;
      case AdminShellSection.devices:
        title = 'Devices';
        body = const AdminDevicesPage();
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(adminAuthServiceProvider).signOut();
              ref.read(adminUidProvider.notifier).state = null;
              if (context.mounted) {
                context.go('/settings');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTokens.space3),
        child: body,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/admin/dashboard');
              break;
            case 1:
              context.go('/admin/shops');
              break;
            case 2:
              context.go('/admin/devices');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shops',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_other_outlined),
            selectedIcon: Icon(Icons.devices_other),
            label: 'Devices',
          ),
        ],
      ),
    );
  }
}
