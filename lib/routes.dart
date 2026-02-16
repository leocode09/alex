import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        return '/money';
      }

      return null;
    },
    routes: [
      // Time tamper lock
      GoRoute(
        path: '/time-lock',
        name: 'time-lock',
        builder: (context, state) => const TimeTamperPage(),
      ),

      // PIN Setup (first time)
      GoRoute(
        path: '/pin-setup',
        name: 'pin-setup',
        builder: (context, state) => PinSetupPage(
          isChangingPin: state.uri.queryParameters['mode'] == 'change',
        ),
      ),

      // PIN Preferences
      GoRoute(
        path: '/pin-preferences',
        name: 'pin-preferences',
        builder: (context, state) => const PinPreferencesPage(),
      ),

      // PIN Entry
      GoRoute(
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
      GoRoute(
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
          GoRoute(
            path: '/money',
            name: 'money',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MoneyPage(),
            ),
          ),
          GoRoute(
            path: '/dashboard',
            redirect: (context, state) => '/money',
          ),

          // Sales
          GoRoute(
            path: '/sales',
            name: 'sales',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SalesPage(),
            ),
          ),

          // Products
          GoRoute(
            path: '/products',
            name: 'products',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProductCatalogPage(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add-product',
                builder: (context, state) {
                  final initialName = state.uri.queryParameters['name'];
                  return AddEditProductPage(initialName: initialName);
                },
              ),
              GoRoute(
                path: ':id',
                name: 'product-details',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ProductDetailsPage(productId: id);
                },
              ),
              GoRoute(
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
          GoRoute(
            path: '/product/add',
            name: 'add-product-alt',
            builder: (context, state) {
              final initialName = state.uri.queryParameters['name'];
              return AddEditProductPage(initialName: initialName);
            },
          ),
          GoRoute(
            path: '/product/edit/:id',
            name: 'edit-product-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AddEditProductPage(productId: id);
            },
          ),
          GoRoute(
            path: '/product/:id',
            name: 'product-details-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ProductDetailsPage(productId: id);
            },
          ),

          // Reports
          GoRoute(
            path: '/reports',
            name: 'reports',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReportsPage(),
            ),
          ),

          // Settings & More
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),

          // LAN Manager
          GoRoute(
            path: '/lan',
            name: 'lan',
            builder: (context, state) => const LanManagerPage(),
          ),

          // Inventory
          GoRoute(
            path: '/inventory',
            name: 'inventory',
            builder: (context, state) => const InventoryPage(),
          ),

          // Categories Management
          GoRoute(
            path: '/categories',
            name: 'categories',
            builder: (context, state) => const CategoryManagementPage(),
          ),

          // Customers
          GoRoute(
            path: '/customers',
            name: 'customers',
            builder: (context, state) => const CustomerListPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'customer-profile',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerProfilePage(customerId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/customer/:id',
            name: 'customer-profile-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerProfilePage(customerId: id);
            },
          ),

          // Employees
          GoRoute(
            path: '/employees',
            name: 'employees',
            builder: (context, state) => const EmployeeListPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'employee-profile',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return EmployeeProfilePage(employeeId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/employee/:id',
            name: 'employee-profile-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return EmployeeProfilePage(employeeId: id);
            },
          ),

          // Stores
          GoRoute(
            path: '/stores',
            name: 'stores',
            builder: (context, state) => const StoresPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'store-details',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return StoreDetailsPage(storeId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/store/:id',
            name: 'store-details-alt',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StoreDetailsPage(storeId: id);
            },
          ),

          // Hardware
          GoRoute(
            path: '/hardware',
            name: 'hardware',
            builder: (context, state) => const HardwareSetupPage(),
          ),

          // Promotions
          GoRoute(
            path: '/promotions',
            name: 'promotions',
            builder: (context, state) => const PromotionsPage(),
          ),

          // Notifications
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
        ],
      ),
    ],
  );
});
