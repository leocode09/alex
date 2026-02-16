import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../helpers/pin_protection.dart';
import '../../services/pin_service.dart';
import '../design_system/app_theme_extensions.dart';
import '../design_system/app_tokens.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return _buildCompactScaffold(context);
        }
        return _buildWideScaffold(context, constraints.maxWidth >= 1100);
      },
    );
  }

  Widget _buildCompactScaffold(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extras = context.appExtras;
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: extras.border, width: AppTokens.border),
          ),
          color: scheme.surface,
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          elevation: 0,
          height: 62,
          backgroundColor: scheme.surface,
          indicatorColor: extras.accentSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _destinations(context),
        ),
      ),
    );
  }

  Widget _buildWideScaffold(BuildContext context, bool extendedRail) {
    final scheme = Theme.of(context).colorScheme;
    final extras = context.appExtras;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: extendedRail ? 210 : 82,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  right: BorderSide(
                    color: extras.border,
                    width: AppTokens.border,
                  ),
                ),
              ),
              child: NavigationRail(
                selectedIndex: currentIndex,
                extended: extendedRail,
                onDestinationSelected: (index) => _onTap(context, index),
                minWidth: 82,
                minExtendedWidth: 210,
                labelType: extendedRail
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                useIndicator: true,
                destinations: _railDestinations(),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: extendedRail ? 1080 : double.infinity,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NavigationDestination> _destinations(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return [
      NavigationDestination(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet, color: primary),
        label: 'Money',
      ),
      NavigationDestination(
        icon: const Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale, color: primary),
        label: 'Sales',
      ),
      NavigationDestination(
        icon: const Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2, color: primary),
        label: 'Products',
      ),
      NavigationDestination(
        icon: const Icon(Icons.assessment_outlined),
        selectedIcon: Icon(Icons.assessment, color: primary),
        label: 'Reports',
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings, color: primary),
        label: 'More',
      ),
    ];
  }

  List<NavigationRailDestination> _railDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: Text('Money'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        label: Text('Sales'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: Text('Products'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.assessment_outlined),
        selectedIcon: Icon(Icons.assessment),
        label: Text('Reports'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('More'),
      ),
    ];
  }

  Future<void> _onTap(BuildContext context, int index) async {
    switch (index) {
      case 0:
        if (await PinProtection.requirePinIfNeeded(
          context,
          isRequired: () => PinService().isPinRequiredForDashboard(),
          title: 'Money Access',
          subtitle: 'Enter PIN to view money accounts',
        )) {
          if (!context.mounted) {
            return;
          }
          context.go('/money');
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
