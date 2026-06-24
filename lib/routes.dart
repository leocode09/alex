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
import 'providers/license_provider.dart';
import 'providers/account_provider.dart';
import 'services/pin_service.dart';
import 'models/license_policy.dart';
import 'models/account_state.dart';
import 'providers/time_tamper_provider.dart';
import 'ui/pages/security/time_tamper_page.dart';
import 'ui/pages/security/license_locked_page.dart';

// Onboarding (business approval)
import 'ui/pages/onboarding/account_login_page.dart';
import 'ui/pages/onboarding/account_register_page.dart';
import 'ui/pages/onboarding/onboarding_page.dart';
import 'ui/pages/onboarding/create_business_page.dart';
import 'ui/pages/onboarding/join_business_page.dart';
import 'ui/pages/onboarding/pending_approval_page.dart';
import 'ui/pages/team/team_management_page.dart';

// Admin
import 'ui/pages/admin/admin_login_page.dart';
import 'ui/pages/admin/admin_shell_page.dart';
import 'ui/pages/admin/admin_shop_detail_page.dart';
import 'ui/pages/admin/admin_device_detail_page.dart';

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
import 'ui/pages/customers/customer_management_page.dart';
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
import 'ui/pages/settings/help_center_page.dart';
import 'ui/pages/settings/about_page.dart';
import 'ui/pages/settings/bonus_rule_page.dart';
import 'ui/pages/lan/lan_manager_page.dart';
import 'ui/pages/cloud/cloud_sync_page.dart';

// Hardware
import 'ui/pages/hardware/hardware_setup_page.dart';

// Promotions
import 'ui/pages/promotions/promotions_page.dart';

// Notifications
import 'ui/pages/notifications/notifications_page.dart';

// Share App (download QR)
import 'ui/pages/share/share_app_page.dart';

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
      location.startsWith('/cloud-sync') ||
      location.startsWith('/inventory') ||
      location.startsWith('/customers') ||
      location.startsWith('/customer') ||
      location.startsWith('/employees') ||
      location.startsWith('/employee') ||
      location.startsWith('/stores') ||
      location.startsWith('/store') ||
      location.startsWith('/hardware') ||
      location.startsWith('/promotions') ||
      location.startsWith('/notifications') ||
      location.startsWith('/share-app') ||
      location.startsWith('/help') ||
      location.startsWith('/about')) {
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
  'editMoneyHistory',
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
      path == '/time-lock' ||
      path == '/share-app' ||
      path == '/help' ||
      path == '/about';
}

bool _isRouteDisabledByPolicy(String path, LicensePolicy policy) {
  if (path.startsWith('/reports')) {
    return !policy.isFeatureEnabled(FeatureKey.reports);
  }
  if (path.startsWith('/cloud-sync')) {
    return !policy.isFeatureEnabled(FeatureKey.cloudSync);
  }
  return false;
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
  if (path.startsWith('/cloud-sync')) {
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

  // Re-run the redirect whenever the license policy or account state
  // changes so remote admin toggles and approval changes apply live.
  // Use a ValueNotifier + ref.listen instead of ref.watch so the
  // GoRouter itself is not rebuilt (which would drop navigation
  // history on every policy tick).
  final policyRefresh = ValueNotifier<int>(0);
  ref.listen(licensePolicyProvider, (_, __) {
    policyRefresh.value = policyRefresh.value + 1;
  });
  ref.listen(accountStateProvider, (_, __) {
    policyRefresh.value = policyRefresh.value + 1;
  });
  ref.onDispose(policyRefresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: policyRefresh,
    redirect: (context, state) async {
      final pinService = PinService();
      final account = ref.read(currentAccountStateProvider);
      await pinService.ensurePinReady(account: account);
      final isPinSet = await pinService.isPinSet();
      final isOnPinSetup = state.uri.path == '/pin-setup';
      final isChangingPinFlow =
          isOnPinSetup && state.uri.queryParameters['mode'] == 'change';
      final isOnPinEntry = state.uri.path == '/pin-entry';
      final isOnLogin = state.uri.path == '/';
      final isOnPinPreferences = state.uri.path == '/pin-preferences';
      final isOnTimeLock = state.uri.path == '/time-lock';
      final isOnLicenseLocked = state.uri.path == '/license-locked';
      final isOnAdminRoute = state.uri.path.startsWith('/admin');
      final isOnOnboarding = state.uri.path.startsWith('/onboarding');
      final isOnPendingApproval = state.uri.path == '/pending-approval';
      final isOnAccountLogin = state.uri.path == '/account-login' ||
          state.uri.path == '/account-register';
      final isOnAccountGate =
          isOnOnboarding || isOnPendingApproval || isOnAccountLogin;
      final canManagePin = await pinService.canManagePinSettings();
      final requireLoginPin = await pinService.isPinRequiredForLogin();
      final isSessionVerified = pinService.isSessionVerified();
      final isUnlocked = pinUnlocked || isSessionVerified;
      final visibilityPrefs = await pinService.getPinPreferences();

      final policy = ref.read(currentLicensePolicyProvider);
      final isBlocked = policy.blockReason() != null;

      // Staff inherit the shop owner's PIN — never show create/change flows.
      if (account.isStaff && (isOnPinSetup || isOnPinPreferences)) {
        return isPinSet ? '/money' : '/';
      }
      if (account.isStaff &&
          isChangingPinFlow &&
          !canManagePin) {
        return isPinSet ? '/money' : '/';
      }

      // Admin routes are always reachable (they are the escape hatch
      // when the install is locked) and the license-locked screen is
      // never auto-redirected away from.
      if (isBlocked && !isOnLicenseLocked && !isOnAdminRoute) {
        return '/license-locked';
      }
      if (!isBlocked && isOnLicenseLocked) {
        return '/money';
      }

      // Business-approval gate. Owners must register and be approved
      // by the system admin; staff must be approved by their owner.
      // Admin routes bypass this so support can fix accounts remotely.
      if (!account.allowsAppAccess && !isOnAdminRoute) {
        switch (account.stage) {
          case AccountStage.signedOut:
            // No user logged in: force the phone + password login.
            if (!isOnAccountLogin) {
              return '/account-login';
            }
            return null;
          case AccountStage.noAccount:
            if (!isOnOnboarding) {
              return '/onboarding';
            }
            return null;
          case AccountStage.businessPending:
          case AccountStage.staffPending:
          case AccountStage.businessRejected:
          case AccountStage.staffRejected:
            if (!isOnPendingApproval) {
              return '/pending-approval';
            }
            return null;
          case AccountStage.unknown:
          case AccountStage.approved:
            // While account state is still loading, keep the user on the
            // account gate (login is the safe entry) instead of letting
            // first-run PIN setup win. If Firebase is unavailable,
            // allowsAppAccess is true and this block is skipped for the
            // local-only fallback.
            if (!isOnAccountGate) {
              return '/account-login';
            }
            return null;
        }
      }

      // The admin panel is a standalone, credential-gated escape hatch:
      // it is guarded by its own email + password Firebase sign-in. Keep
      // every /admin route reachable even when no local PIN is set or the
      // install is PIN / time locked, so an admin can always sign in to
      // fix accounts. (The license and approval gates above already let
      // admin routes through; this additionally clears the PIN / time-lock
      // redirects below — otherwise a logged-out admin gets bounced to the
      // welcome or PIN screen and can never reach the sign-in form.)
      if (isOnAdminRoute) {
        return null;
      }

      // Once approved, never strand the user on an onboarding/pending
      // screen.
      if (account.allowsAppAccess &&
          account.stage == AccountStage.approved &&
          isOnAccountGate) {
        return '/money';
      }

      if (timeTamper != null && isPinSet && !isOnTimeLock) {
        return '/time-lock';
      }

      if (timeTamper == null && isOnTimeLock) {
        return '/money';
      }

      // First time — show the login/welcome screen before PIN setup.
      // PIN setup is reached from [LoginPage] when the user continues.
      // Staff never create a PIN; they wait for the owner's shop PIN.
      if (!isPinSet && !isOnPinSetup && !isOnLogin) {
        return '/';
      }
      if (!isPinSet && !canManagePin && isOnPinSetup) {
        return '/';
      }

      // PIN is set and required for login but not unlocked (need PIN entry).
      // Skip when on time-lock: that flow verifies PIN via PinProtection on the
      // tamper page; sending users to /pin-entry would loop (tamper redirect wins).
      if (isPinSet &&
          requireLoginPin &&
          !isUnlocked &&
          !isOnPinEntry &&
          !isOnTimeLock) {
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

      if (isUnlocked && _isRouteDisabledByPolicy(state.uri.path, policy)) {
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

      // License lock (admin remotely disabled / expired / blocked).
      _animatedRoute(
        path: '/license-locked',
        name: 'license-locked',
        builder: (context, state) => const LicenseLockedPage(),
      ),

      // Account login / register (phone + password identity).
      _animatedRoute(
        path: '/account-login',
        name: 'account-login',
        builder: (context, state) => const AccountLoginPage(),
      ),
      _animatedRoute(
        path: '/account-register',
        name: 'account-register',
        builder: (context, state) => const AccountRegisterPage(),
      ),

      // Business approval workflow (account onboarding).
      _animatedRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
        routes: [
          _animatedRoute(
            path: 'create-business',
            name: 'onboarding-create-business',
            builder: (context, state) => const CreateBusinessPage(),
          ),
          _animatedRoute(
            path: 'join-business',
            name: 'onboarding-join-business',
            builder: (context, state) => const JoinBusinessPage(),
          ),
        ],
      ),
      _animatedRoute(
        path: '/pending-approval',
        name: 'pending-approval',
        builder: (context, state) => const PendingApprovalPage(),
      ),

      // Admin login (hidden entry from settings long-press).
      _animatedRoute(
        path: '/admin-login',
        name: 'admin-login',
        builder: (context, state) => const AdminLoginPage(),
      ),

      // Admin shell + nested pages.
      _animatedRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminShellPage(
          section: AdminShellSection.dashboard,
        ),
      ),
      _animatedRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminShellPage(
          section: AdminShellSection.dashboard,
        ),
      ),
      _animatedRoute(
        path: '/admin/shops',
        name: 'admin-shops',
        builder: (context, state) => AdminShellPage(
          section: AdminShellSection.shops,
          filter: state.uri.queryParameters['filter'],
        ),
      ),
      _animatedRoute(
        path: '/admin/shops/:id',
        name: 'admin-shop-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AdminShopDetailPage(shopId: id);
        },
      ),
      _animatedRoute(
        path: '/admin/devices',
        name: 'admin-devices',
        builder: (context, state) => AdminShellPage(
          section: AdminShellSection.devices,
          filter: state.uri.queryParameters['filter'],
        ),
      ),
      _animatedRoute(
        path: '/admin/devices/:id',
        name: 'admin-device-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AdminDeviceDetailPage(installId: id);
        },
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
            routes: [
              _animatedRoute(
                path: 'bonus-rule',
                name: 'settings-bonus-rule',
                builder: (context, state) => const BonusRulePage(),
              ),
            ],
          ),

          // Team / staff management (owner-only view of pending and
          // approved staff requests for the current business).
          _animatedRoute(
            path: '/team',
            name: 'team',
            builder: (context, state) => const TeamManagementPage(),
          ),

          // LAN Manager
          _animatedRoute(
            path: '/lan',
            name: 'lan',
            builder: (context, state) => const LanManagerPage(),
          ),

          // Cloud sync (Firestore backup + live two-way sync)
          _animatedRoute(
            path: '/cloud-sync',
            name: 'cloud-sync',
            builder: (context, state) => const CloudSyncPage(),
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
                path: 'manage',
                name: 'customer-management',
                builder: (context, state) => const CustomerManagementPage(),
              ),
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

          // Share App (QR code to download on another device)
          _animatedRoute(
            path: '/share-app',
            name: 'share-app',
            builder: (context, state) => const ShareAppPage(),
          ),

          // Help Center and About (under "More")
          _animatedRoute(
            path: '/help',
            name: 'help',
            builder: (context, state) => const HelpCenterPage(),
          ),
          _animatedRoute(
            path: '/about',
            name: 'about',
            builder: (context, state) => const AboutPage(),
          ),
        ],
      ),
    ],
  );
});
