import 'package:alex/models/sale.dart';
import 'package:alex/providers/sale_provider.dart';
import 'package:alex/ui/pages/sales/receipts_page.dart';
import 'package:alex/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Sale buildSale({
    required String id,
    required String itemName,
    required double total,
    required String paymentMethod,
  }) {
    return Sale(
      id: id,
      items: [
        SaleItem(
          productId: '$id-item',
          productName: itemName,
          quantity: 1,
          price: total,
        ),
      ],
      total: total,
      paymentMethod: paymentMethod,
      employeeId: 'tester',
      createdAt: DateTime(2026, 2, 13, 9, 45),
    );
  }

  testWidgets('receipts tab filters receipts by broad search query',
      (tester) async {
    final sales = [
      buildSale(
        id: 'sale-apple-001',
        itemName: 'Apple Juice',
        total: 10.00,
        paymentMethod: 'Cash',
      ),
      buildSale(
        id: 'sale-banana-002',
        itemName: 'Banana Bread',
        total: 25.00,
        paymentMethod: 'Card',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesProvider.overrideWith((ref) async => sales),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: ReceiptsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\$10.00'), findsOneWidget);
    expect(find.text('\$25.00'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'banana',
    );
    await tester.pumpAndSettle();

    expect(find.text('\$25.00'), findsOneWidget);
    expect(find.text('\$10.00'), findsNothing);
  });
}
