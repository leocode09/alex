import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/admin_auth_provider.dart';
import '../../../services/cloud/firestore_paths.dart';
import '../../design_system/app_tokens.dart';
import 'admin_dashboard_page.dart';
import 'admin_devices_page.dart';
import 'admin_heuristics.dart';
import 'admin_shops_page.dart';
import 'widgets/admin_global_search_sheet.dart';

/// Sections of the admin panel. The shell renders one at a time and
/// switches via the bottom-nav / tab bar.
enum AdminShellSection { dashboard, shops, devices }

class AdminShellPage extends ConsumerStatefulWidget {
  final AdminShellSection section;

  /// Optional filter query param forwarded from the route (e.g.
  /// `?filter=offline` on `/admin/devices`).
  final String? filter;

  const AdminShellPage({super.key, required this.section, this.filter});

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
        body = AdminShopsPage.withQueryFilter(widget.filter);
        break;
      case AdminShellSection.devices:
        title = 'Devices';
        body = AdminDevicesPage.withQueryFilter(widget.filter);
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
            tooltip: 'Global search',
            icon: const Icon(Icons.search),
            onPressed: () => showAdminGlobalSearchSheet(context),
          ),
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
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: _ShopsNavIcon(selected: false, db: ref.watch(adminAuthServiceProvider).db),
            selectedIcon:
                _ShopsNavIcon(selected: true, db: ref.watch(adminAuthServiceProvider).db),
            label: 'Shops',
          ),
          const NavigationDestination(
            icon: Icon(Icons.devices_other_outlined),
            selectedIcon: Icon(Icons.devices_other),
            label: 'Devices',
          ),
        ],
      ),
    );
  }
}

class _ShopsNavIcon extends StatelessWidget {
  final bool selected;
  final FirebaseFirestore? db;

  const _ShopsNavIcon({required this.selected, required this.db});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? Icons.storefront : Icons.storefront_outlined,
    );
    if (db == null) return icon;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db!.collection(FirestorePaths.shopsCollection).snapshots(),
      builder: (context, snap) {
        final pending = (snap.data?.docs ?? const []).where(
          (d) =>
              AdminHeuristics.approvalStatus(d.data()) ==
              ApprovalStatus.pendingSystemAdmin,
        ).length;
        if (pending <= 0) return icon;
        return Badge(
          label: Text(pending > 9 ? '9+' : '$pending'),
          child: icon,
        );
      },
    );
  }
}
