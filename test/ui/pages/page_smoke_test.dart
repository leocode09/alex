import 'package:alex/ui/pages/auth/login_page.dart';
import 'package:alex/ui/pages/auth/pin_entry_page.dart';
import 'package:alex/ui/pages/auth/pin_preferences_page.dart';
import 'package:alex/ui/pages/auth/pin_setup_page.dart';
import 'package:alex/ui/pages/customers/customer_list_page.dart';
import 'package:alex/ui/pages/customers/customer_profile_page.dart';
import 'package:alex/ui/pages/employees/employee_list_page.dart';
import 'package:alex/ui/pages/employees/employee_profile_page.dart';
import 'package:alex/ui/pages/hardware/hardware_setup_page.dart';
import 'package:alex/ui/pages/notifications/notifications_page.dart';
import 'package:alex/ui/pages/promotions/promotions_page.dart';
import 'package:alex/ui/pages/security/time_tamper_page.dart';
import 'package:alex/ui/pages/settings/settings_page.dart';
import 'package:alex/ui/pages/stores/store_details_page.dart';
import 'package:alex/ui/pages/stores/stores_page.dart';
import 'package:alex/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    bool withProviders = false,
  }) async {
    Widget app = MaterialApp(
      theme: AppTheme.lightTheme,
      home: page,
    );
    if (withProviders) {
      app = ProviderScope(child: app);
    }
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('main pages render without immediate crash', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1200, 2400));

    await pumpPage(tester, const LoginPage(), withProviders: true);
    await pumpPage(tester, const SettingsPage(), withProviders: true);
    await pumpPage(tester, const StoresPage());
    await pumpPage(tester, const StoreDetailsPage(storeId: '1'));
    await pumpPage(tester, const CustomerListPage());
    await pumpPage(tester, const CustomerProfilePage(customerId: '1'));
    await pumpPage(tester, const EmployeeListPage());
    await pumpPage(tester, const EmployeeProfilePage(employeeId: '1'));
    await pumpPage(tester, const HardwareSetupPage());
    await pumpPage(tester, const PromotionsPage());
    await pumpPage(tester, const NotificationsPage());
    await pumpPage(tester, const PinEntryPage());
    await pumpPage(tester, const PinSetupPage());
    await pumpPage(tester, const PinPreferencesPage());
    await pumpPage(tester, const TimeTamperPage(), withProviders: true);

    expect(find.byType(Scaffold), findsWidgets);
  });
}
