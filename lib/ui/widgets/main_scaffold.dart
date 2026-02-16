import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../helpers/pin_protection.dart';
import '../../services/pin_service.dart';
import '../design_system/app_theme_extensions.dart';
import '../design_system/app_tokens.dart';

const List<String> _moneyVisibilityKeys = [
  'dashboard',
  'addMoneyAccount',
  'editMoneyAccount',
  'deleteMoneyAccount',
  'addMoney',
  'removeMoney',
  'viewMoneyHistory',
];

const List<String> _salesVisibilityKeys = [
  'createSale',
  'viewSalesHistory',
  'editReceipt',
  'deleteReceipt',
  'applyDiscount',
  'issueRefund',
];

const List<String> _productVisibilityKeys = [
  'addProduct',
  'editProduct',
  'deleteProduct',
  'viewProductDetails',
  'scanBarcode',
  'adjustStock',
];

const List<String> _settingsVisibilityKeys = [
  'settings',
];

class _NavItem {
  const _NavItem({
    required this.slotIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.visibilityKeys,
    this.isPinRequired,
    this.pinTitle,
    this.pinSubtitle,
  });

  final int slotIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final List<String> visibilityKeys;
  final Future<bool> Function(PinService service)? isPinRequired;
  final String? pinTitle;
  final String? pinSubtitle;
}

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
    return FutureBuilder<Map<String, bool>>(
      future: PinService().getPinPreferences(),
      builder: (context, snapshot) {
        final preferences = snapshot.data ?? const <String, bool>{};
        final navItems = _visibleNavItems(preferences);
        final selectedIndex = _resolveSelectedIndex(navItems);

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 700) {
              return _buildCompactScaffold(
                context,
                navItems: navItems,
                selectedIndex: selectedIndex,
              );
            }
            return _buildWideScaffold(
              context,
              constraints.maxWidth >= 1100,
              navItems: navItems,
              selectedIndex: selectedIndex,
            );
          },
        );
      },
    );
  }

  List<_NavItem> _allNavItems() {
    return [
      _NavItem(
        slotIndex: 0,
        label: 'Money',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        route: '/money',
        visibilityKeys: _moneyVisibilityKeys,
        isPinRequired: (service) => service.isPinRequiredForDashboard(),
        pinTitle: 'Money Access',
        pinSubtitle: 'Enter PIN to view money accounts',
      ),
      const _NavItem(
        slotIndex: 1,
        label: 'Sales',
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        route: '/sales',
        visibilityKeys: _salesVisibilityKeys,
      ),
      const _NavItem(
        slotIndex: 2,
        label: 'Products',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        route: '/products',
        visibilityKeys: _productVisibilityKeys,
      ),
      _NavItem(
        slotIndex: 3,
        label: 'Reports',
        icon: Icons.assessment_outlined,
        selectedIcon: Icons.assessment,
        route: '/reports',
        visibilityKeys: const [
          'reports',
          'viewFinancialReports',
          'viewInventoryReports',
          'exportReports'
        ],
        isPinRequired: (service) => service.isPinRequiredForReports(),
        pinTitle: 'Reports Access',
        pinSubtitle: 'Enter PIN to view reports',
      ),
      _NavItem(
        slotIndex: 4,
        label: 'More',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        route: '/settings',
        visibilityKeys: _settingsVisibilityKeys,
        isPinRequired: (service) => service.isPinRequiredForSettings(),
        pinTitle: 'Settings Access',
        pinSubtitle: 'Enter PIN to access settings',
      ),
    ];
  }

  List<_NavItem> _visibleNavItems(Map<String, bool> preferences) {
    return _allNavItems().where((item) {
      return item.visibilityKeys.any((featureKey) {
        return preferences[PinService.visiblePreferenceKey(featureKey)] ?? true;
      });
    }).toList();
  }

  int _resolveSelectedIndex(List<_NavItem> navItems) {
    if (navItems.isEmpty) {
      return 0;
    }
    final index = navItems.indexWhere((item) => item.slotIndex == currentIndex);
    return index >= 0 ? index : 0;
  }

  Widget _buildCompactScaffold(
    BuildContext context, {
    required List<_NavItem> navItems,
    required int selectedIndex,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final extras = context.appExtras;

    if (navItems.isEmpty) {
      return Scaffold(body: child);
    }

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
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _onTap(context, navItems[index]),
          elevation: 0,
          height: 62,
          backgroundColor: scheme.surface,
          indicatorColor: extras.accentSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _destinations(context, navItems),
        ),
      ),
    );
  }

  Widget _buildWideScaffold(
    BuildContext context,
    bool extendedRail, {
    required List<_NavItem> navItems,
    required int selectedIndex,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final extras = context.appExtras;

    if (navItems.isEmpty) {
      return Scaffold(body: child);
    }

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
                selectedIndex: selectedIndex,
                extended: extendedRail,
                onDestinationSelected: (index) =>
                    _onTap(context, navItems[index]),
                minWidth: 82,
                minExtendedWidth: 210,
                labelType: extendedRail
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                useIndicator: true,
                destinations: _railDestinations(navItems),
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

  List<NavigationDestination> _destinations(
    BuildContext context,
    List<_NavItem> navItems,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return navItems
        .map(
          (item) => NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon, color: primary),
            label: item.label,
          ),
        )
        .toList();
  }

  List<NavigationRailDestination> _railDestinations(List<_NavItem> navItems) {
    return navItems
        .map(
          (item) => NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
        )
        .toList();
  }

  Future<void> _onTap(BuildContext context, _NavItem item) async {
    if (item.isPinRequired != null) {
      final allowed = await PinProtection.requirePinIfNeeded(
        context,
        isRequired: () => item.isPinRequired!(PinService()),
        title: item.pinTitle ?? 'Restricted Feature',
        subtitle: item.pinSubtitle ?? 'Enter PIN to continue',
      );
      if (!allowed) {
        return;
      }
    }

    if (!context.mounted) {
      return;
    }
    context.go(item.route);
  }
}
