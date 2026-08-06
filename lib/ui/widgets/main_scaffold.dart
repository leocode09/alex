import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../helpers/pin_protection.dart';
import '../../services/pin_service.dart';
import '../design_system/app_theme_extensions.dart';
import '../design_system/app_tokens.dart';

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

class MainScaffold extends StatefulWidget {
  final Widget child;
  final int currentIndex;

  const MainScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // Created once (and re-created only when PIN preferences actually
  // change) instead of on every build, so navigation never flashes or
  // reflows while a freshly created future resolves.
  late Future<Map<String, bool>> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = PinService().getPinPreferences();
    PinService.preferencesRevision.addListener(_onPreferencesChanged);
  }

  @override
  void dispose() {
    PinService.preferencesRevision.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  void _onPreferencesChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _preferencesFuture = PinService().getPinPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: _preferencesFuture,
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
      const _NavItem(
        slotIndex: 0,
        label: 'Sales',
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        route: '/sales',
        visibilityKeys: _salesVisibilityKeys,
      ),
      const _NavItem(
        slotIndex: 1,
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        route: '/products',
        visibilityKeys: _productVisibilityKeys,
      ),
      _NavItem(
        slotIndex: 2,
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
        slotIndex: 3,
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
    final index =
        navItems.indexWhere((item) => item.slotIndex == widget.currentIndex);
    return index >= 0 ? index : 0;
  }

  Widget _buildCompactScaffold(
    BuildContext context, {
    required List<_NavItem> navItems,
    required int selectedIndex,
  }) {
    final extras = context.appExtras;

    if (navItems.isEmpty) {
      return Scaffold(backgroundColor: Colors.transparent, body: widget.child);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: widget.child,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: AppTokens.blurBar,
            sigmaY: AppTokens.blurBar,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: extras.glassBorder,
                  width: AppTokens.border,
                ),
              ),
              color: extras.glassFill,
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  _onTap(context, navItems[index]),
              elevation: 0,
              height: 62,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              indicatorColor: extras.accentSoft,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: _destinations(context, navItems),
            ),
          ),
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
    final extras = context.appExtras;

    if (navItems.isEmpty) {
      return Scaffold(backgroundColor: Colors.transparent, body: widget.child);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Row(
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: AppTokens.blurBar,
                  sigmaY: AppTokens.blurBar,
                ),
                child: Container(
                  width: extendedRail ? 210 : 82,
                  decoration: BoxDecoration(
                    color: extras.glassFill,
                    border: Border(
                      right: BorderSide(
                        color: extras.glassBorder,
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
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: extendedRail ? 1080 : double.infinity,
                  ),
                  child: widget.child,
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
