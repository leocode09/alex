import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../helpers/pin_protection.dart';
import '../../services/pin_service.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const MainScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
          color: Colors.white,
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          elevation: 0,
          height: 65,
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: Theme.of(context).colorScheme.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: const Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale, color: Theme.of(context).colorScheme.primary),
              label: 'Sales',
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
              label: 'Products',
            ),
            NavigationDestination(
              icon: const Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment, color: Theme.of(context).colorScheme.primary),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, int index) async {
    switch (index) {
      case 0:
        if (await PinProtection.requirePinIfNeeded(
          context,
          isRequired: () => PinService().isPinRequiredForDashboard(),
          title: 'Dashboard Access',
          subtitle: 'Enter PIN to view dashboard',
        )) {
          if (!context.mounted) {
            return;
          }
          context.go('/dashboard');
        }
        break;
      case 1:
        context.go('/sales');
        break;
      case 2:
        context.go('/products');
        break;
      case 3:
        if (await PinProtection.requirePinIfNeeded(
          context,
          isRequired: () => PinService().isPinRequiredForReports(),
          title: 'Reports Access',
          subtitle: 'Enter PIN to view reports',
        )) {
          if (!context.mounted) {
            return;
          }
          context.go('/reports');
        }
        break;
      case 4:
        if (await PinProtection.requirePinIfNeeded(
          context,
          isRequired: () => PinService().isPinRequiredForSettings(),
          title: 'Settings Access',
          subtitle: 'Enter PIN to access settings',
        )) {
          if (!context.mounted) {
            return;
          }
          context.go('/settings');
        }
        break;
    }
  }
}
