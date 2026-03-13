import 'dart:convert';

import 'package:alex/ui/pages/money/money_page.dart';
import 'package:alex/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MoneyPage shows edit affordance when history exists', (tester) async {
    final accountId = 'acc_test_1';
    final historyRecord = {
      'id': 'mh_test_1',
      'accountId': accountId,
      'accountName': 'Test Account',
      'action': 'money_added',
      'amount': 50,
      'balanceBefore': 100,
      'balanceAfter': 150,
      'note': 'Deposit',
      'createdAt': DateTime.now().toIso8601String(),
    };
    final account = {
      'id': accountId,
      'name': 'Test Account',
      'balance': 150,
      'note': null,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    SharedPreferences.setMockInitialValues({
      'money_accounts': jsonEncode([account]),
      'money_account_history': jsonEncode([historyRecord]),
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MoneyPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MoneyPage), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
  });
}
