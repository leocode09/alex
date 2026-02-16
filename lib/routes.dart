import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/design_system/app_route_transitions.dart';

// Widgets
import 'ui/widgets/main_scaffold.dart';

// Auth
import 'ui/pages/auth/login_page.dart';
import 'ui/pages/auth/pin_setup_page.dart';
import 'ui/pages/auth/pin_entry_page.dart';
import 'ui/pages/auth/pin_preferences_page.dart';
import 'providers/pin_unlock_provider.dart';
import 'services/pin_service.dart';
import 'providers/time_tamper_provider.dart';
import 'ui/pages/security/time_tamper_page.dart';

// Money
import 'ui/pages/money/money_page.dart';

// Sales
import 'ui/pages/sales/sales_page.dart';

// Products
import 'ui/pages/products/product_catalog_page.dart';
import 'ui/pages/products/product_details_page.dart';
import 'ui/pages/products/add_edit_product_page.dart';

// Categories
import 'ui/pages/categories/category_management_page.dart';

// Inventory
import 'ui/pages/inventory/inventory_page.dart';

// Customers
import 'ui/pages/customers/customer_list_page.dart';
import 'ui/pages/customers/customer_profile_page.dart';

// Reports
import 'ui/pages/reports/reports_page.dart';

// Employees
import 'ui/pages/employees/employee_list_page.dart';
import 'ui/pages/employees/employee_profile_page.dart';

// Stores
import 'ui/pages/stores/stores_page.dart';
import 'ui/pages/stores/store_details_page.dart';

// Settings
import 'ui/pages/settings/settings_page.dart';
import 'ui/pages/lan/lan_manager_page.dart';

// Hardware
import 'ui/pages/hardware/hardware_setup_page.dart';

// Promotions
import 'ui/pages/promotions/promotions_page.dart';

// Notifications
import 'ui/pages/notifications/notifications_page.dart';

// Navigation state key
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRoute _animatedRoute({
  required String path,
  String? name,
  GoRouterRedirect? redirect,
  Widget Function(BuildContext context, GoRouterState state)? builder,
  List<RouteBase> routes = const <RouteBase>[],
}) {
  return GoRoute(
    path: path,
    name: name,
    redirect: redirect,
    routes: routes,
    pageBuilder: builder == null
        ? null
        : (context, state) => AppRouteTransitions.build(
              state: state,
              child: builder(context, state),
            ),
  );
}

// Helper to get current index based on location
int _getCurrentIndex(String location) {
  if (location.startsWith('/money')) return 0;
  if (location.startsWith('/dashboard')) return 0;
  if (location.startsWith('/sales')) return 1;
  if (location.startsWith('/products') || location.startsWith('/product')) {
    return 2;
  }
  if (location.startsWith('/reports')) return 3;
  if (location.startsWith('/settings') ||
      location.startsWith('/lan') ||
      location.startsWith('/inventory') ||
      location.startsWith('/customers') ||
      location.startsWith('/customer') ||
      location.startsWith('/employees') ||
      location.startsWith('/employee') ||
      location.startsWith('/stores') ||
      location.startsWith('/store') ||
      location.startsWith('/hardware') ||
      location.startsWith('/promotions') ||
      location.startsWith('/notifications')) {
    return 4;
  }
  return 0;
}

const List<String> _moneyFeatureKeys = [
  'dashboard',
  'addMoneyAccount',
  'editMoneyAccount',
  'deleteMoneyAccount',
  'addMoney',
  'removeMoney',
  'viewMoneyHistory',
];

const List<String> _salesFeatureKeys = [
  'createSale',
  'viewSalesHistory',
  'editReceipt',
  'deleteReceipt',
  'applyDiscount',
  'issueRefund',
];

const List<String> _productFeatureKeys = [
  'addProduct',
  'editProduct',
  'deleteProduct',
  'viewProductDetails',
  'scanBarcode',
  'adjustStock',
];

const List<String> _categoryFeatureKeys = [
  'viewCategories',
  'addCategory',
  'editCategory',
  'deleteCategory',
];

const List<String> _customerFeatureKeys = [
  'viewCustomers',
  'addCustomer',
  'editCustomer',
  'deleteCustomer',
];

const List<String> _employeeFeatureKeys = [
  'viewEmployees',
  'addEmployee',
  'editEmployee',
  'deleteEmployee',
];

const List<String> _storeFeatureKeys = [
  'viewStores',
  'addStore',
  'editStore',
  'deleteStore',
];

const List<String> _reportFeatureKeys = [
  'reports',
  'viewFinancialReports',
  'viewInventoryReports',
  'exportReports',
];

bool _isFeatureVisible(Map<String, bool> prefs, String featureKey) {
  return prefs[PinService.visiblePreferenceKey(featureKey)] ?? true;
}

bool _isAnyFeatureVisible(Map<String, bool> prefs, List<String> featureKeys) {
  return featureKeys.any((key) => _isFeatureVisible(prefs, key));
}

bool _isPathVisibilityExempt(String path) {
  return path == '/' ||
      path == '/pin-entry' ||
      path == '/pin-setup' ||
      path == '/pin-preferences' ||
      path == '/time-lock';
}

bool _isRouteHiddenByPreferences(String path, Map<String, bool> prefs) {
  if (path.startsWith('/money') || path.startsWith('/dashboard')) {
    return !_isAnyFeatureVisible(prefs, _moneyFeatureKeys);
  }
  if (path.startsWith('/sales')) {
    return !_isAnyFeatureVisible(prefs, _salesFeatureKeys);
  }
  if (path.startsWith('/products') || path.startsWith('/product')) {
    return !_isAnyFeatureVisible(prefs, _productFeatureKeys);
  }
  if (path.startsWith('/reports')) {
    return !_isAnyFeatureVisible(prefs, _reportFeatureKeys);
  }
  if (path.startsWith('/settings')) {
    return !_isFeatureVisible(prefs, 'settings');
  }
  if (path.startsWith('/inventory')) {
    return !_isFeatureVisible(prefs, 'adjustStock');
  }
  if (path.startsWith('/categories')) {
    return !_isAnyFeatureVisible(prefs, _categoryFeatureKeys);
  }
  if (path.startsWith('/customers') || path.startsWith('/customer')) {
    return !_isAnyFeatureVisible(prefs, _customerFeatureKeys);
  }
  if (path.startsWith('/employees') || path.startsWith('/employee')) {
    return !_isAnyFeatureVisible(prefs, _employeeFeatureKeys);
  }
  if (path.startsWith('/stores') || path.startsWith('/store')) {
    return !_isAnyFeatureVisible(prefs, _storeFeatureKeys);
  }
  if (path.startsWith('/hardware')) {
    return !_isFeatureVisible(prefs, 'hardwareSetup');
  }
  if (path.startsWith('/lan')) {
    return !_isFeatureVisible(prefs, 'dataSync');
  }
  if (path.startsWith('/promotions')) {
    return !_isFeatureVisible(prefs, 'managePromotions');
  }
  if (path.startsWith('/notifications')) {
    return !_isFeatureVisible(prefs, 'viewNotifications');
  }
  return false;
}

String _firstVisibleRoute(Map<String, bool> prefs) {
  if (_isAnyFeatureVisible(prefs, _moneyFeatureKeys)) {
    return '/money';
  }
  if (_isAnyFeatureVisible(prefs, _salesFeatureKeys)) {
    return '/sales';
  }
  if (_isAnyFeatureVisible(prefs, _productFeatureKeys)) {
    return '/products';
  }
  if (_isAnyFeatureVisible(prefs, _reportFeatureKeys)) {
    return '/reports';
  }
  if (_isFeatureVisible(prefs, 'settings')) {
    return '/settings';
  }
  if (_isAnyFeatureVisible(prefs, _storeFeatureKeys)) {
    return '/stores';
  }
  if (_isAnyFeatureVisible(prefs, _employeeFeatureKeys)) {
    return '/employees';
  }
  if (_isAnyFeatureVisible(prefs, _customerFeatureKeys)) {
    return '/customers';
  }
  if (_isAnyFeatureVisible(prefs, _categoryFeatureKeys)) {
    return '/categories';
  }
  if (_isFeatureVisible(prefs, 'adjustStock')) {
    return '/inventory';
  }
  if (_isFeatureVisible(prefs, 'hardwareSetup')) {
    return '/hardware';
  }
  if (_isFeatureVisible(prefs, 'dataSync')) {
    return '/lan';
  }
  if (_isFeatureVisible(prefs, 'managePromotions')) {
    return '/promotions';
  }
  if (_isFeatureVisible(prefs, 'viewNotifications')) {
    return '/notifications';
  }
  return '/pin-preferences';
}

final routerProvider = Provider<GoRouter>((ref) {
  final pinUnlocked = ref.watch(pinUnlockedProvider);
  final timeTamper = ref.watch(timeTamperProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) async {
      final pinService = PinService();
      final isPinSet = await pinService.isPinSet();
      final isOnPinSetup = state.uri.path == '/pin-setup';
      final isChangingPinFlow =
          isOnPinSetup && state.uri.queryParameters['mode'] == 'change';
      final isOnPinEntry = state.uri.path == '/pin-entry';
      final isOnLogin = state.uri.path == '/';
      final isOnTimeLock = state.uri.path == '/time-lock';
      final requireLoginPin = await pinService.isPinRequiredForLogin();
      final isSessionVerified = pinService.isSessionVerified();
      final isUnlocked = pinUnlocked || isSessionVerified;
      final visibilityPrefs = await pinService.getPinPreferences();

      if (timeTamper != null && isPinSet && !isOnTimeLock) {
        return '/time-lock';
      }

      if (timeTamper == null && isOnTimeLock) {
        return '/money';
      }

      // First time - need to setup PIN
      if (!isPinSet && !isOnPinSetup) {
        return '/pin-setup';
      }

      // PIN is set and required for login but not unlocked (need PIN entry)
      if (isPinSet && requireLoginPin && !isUnlocked && !isOnPinEntry) {
        return '/pin-entry';
      }

      // Unlocked but on login/pin pages
      if (isUnlocked &&
          (isOnLogin || isOnPinEntry || (isOnPinSetup && !isChangingPinFlow))) {
        return _firstVisibleRoute(visibilityPrefs);
      }

      if (isUnlocked &&
          !_isPathVisibilityExempt(state.uri.path) &&
          _isRouteHiddenByPreferences(state.uri.path, visibilityPrefs)) {
        return _firstVisibleRoute(visibilityPrefs);
      }

      return null;
    },
    routes: [
      // Time tamper lock
      _animatedRoute(
        path: '/time-lock',
        name: 'time-lock',
        builder: (context, state) => const TimeTamperPage(),
      ),

      // PIN Setup (first time)
      _animatedRoute(
        path: '/pin-setup',
        name: 'pin-setup',
        builder: (context, state) => PinSetupPage(
          isChangingPin: state.uri.queryParameters['mode'] == 'change',
        ),
      ),

      // PIN Preferences
      _animatedRoute(
        path: '/pin-preferences',
        name: 'pin-preferences',
        builder: (context, state) => const PinPreferencesPage(),
      ),

      // PIN Entry
      _animatedRoute(
        path: '/pin-entry',
        name: 'pin-entry',
        builder: (context, state) => PinEntryPage(
          title: 'Welcome Back',
          subtitle: 'Enter your PIN to continue',
          canGoBack: false,
          popOnSuccess: false,
          onSuccess: () async {
            ref.read(pinUnlockedProvider.notifier).state = true;
            if (context.mounted) {
              context.go('/money');
            }
          },
        ),
      ),

      // Auth (no bottom bar)
      _animatedRoute(
        path: '/',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // Main app with persistent bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainScaffold(
            currentIndex: _getCurrentIndex(state.uri.path),
            child: child,
          );
        },
        routes: [
          // Money
          _animatedRoute(
            path: '/money',
            name: 'money',
            builder: (context, state) => const MoneyPage(),
          ),
          _animatedRoute(
            path: '/dashboard',
            redirect: (context, state) => '/money',
          ),

          // Sales
          _animatedRoute(
            path: '/sales',
            name: 'sales',
            builder: (context, state) => const SalesPage(),
          ),

          // Products
          _animatedRoute(
            path: '/products',
            name: 'products',
            builder: (context, state) => const ProductCatalogPage(),
            routes: [
              _animatedRoute(
                path: 'add',
                name: 'add-product',
                builder: (context, state) {
                  final initialName = state.uri.queryParameters['name'];
                  return AddEditProductPage(initialName: initialName);
                },
              ),
              _animatedRoute(
                path: ':id',
                name: 'product-details',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ProductDetailsPage(productId: id);
                },
              ),
              _animatedRoute(
                path: 'edit/:id',
                name: 'edit-product',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return AddEditProductPage(productId: id);
                },
              ),
            ],
          ),

          // Product routes (singular for compatibility)
          // Note: Literal paths must come before parameterized paths
          _animatedRoute(
            path: '/product/add',
            name: 'add-product-alt',
            builder: (context, state) {
              final initialName = state.uri.queryParameters['name'];
              return AddEditProductPage(initialName: initialName);
            },
          ),
          _animatedRoute(
            path: '/product/edit/:id',
            name: 'edit-product-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AddEditProductPage(productId: id);
            },
          ),
          _animatedRoute(
            path: '/product/:id',
            name: 'product-details-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductDetailsPage(productId: id);
            },
          ),

          // Reports
          _animatedRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsPage(),
          ),

          // Settings & More
          _animatedRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),

          // LAN Manager
          _animatedRoute(
            path: '/lan',
            name: 'lan',
            builder: (context, state) => const LanManagerPage(),
          ),

          // Inventory
          _animatedRoute(
            path: '/inventory',
            name: 'inventory',
            builder: (context, state) => const InventoryPage(),
          ),

          // Categories Management
          _animatedRoute(
            path: '/categories',
            name: 'categories',
            builder: (context, state) => const CategoryManagementPage(),
          ),

          // Customers
          _animatedRoute(
            path: '/customers',
            name: 'customers',
            builder: (context, state) => const CustomerListPage(),
            routes: [
              _animatedRoute(
                path: ':id',
                name: 'customer-profile',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerProfilePage(customerId: id);
                },
              ),
            ],
          ),
          _animatedRoute(
            path: '/customer/:id',
            name: 'customer-profile-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerProfilePage(customerId: id);
            },
          ),

          // Employees
          _animatedRoute(
            path: '/employees',
            name: 'employees',
            builder: (context, state) => const EmployeeListPage(),
            routes: [
              _animatedRoute(
                path: ':id',
                name: 'employee-profile',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return EmployeeProfilePage(employeeId: id);
                },
              ),
            ],
          ),
          _animatedRoute(
            path: '/employee/:id',
            name: 'employee-profile-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return EmployeeProfilePage(employeeId: id);
            },
          ),

          // Stores
          _animatedRoute(
            path: '/stores',
            name: 'stores',
            builder: (context, state) => const StoresPage(),
            routes: [
              _animatedRoute(
                path: ':id',
                name: 'store-details',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return StoreDetailsPage(storeId: id);
                },
              ),
            ],
          ),
          _animatedRoute(
            path: '/store/:id',
            name: 'store-details-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StoreDetailsPage(storeId: id);
            },
          ),

          // Hardware
          _animatedRoute(
            path: '/hardware',
            name: 'hardware',
            builder: (context, state) => const HardwareSetupPage(),
          ),

          // Promotions
          _animatedRoute(
            path: '/promotions',
            name: 'promotions',
            builder: (context, state) => const PromotionsPage(),
          ),

          // Notifications
          _animatedRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
        ],
      ),
    ],
  );
});
