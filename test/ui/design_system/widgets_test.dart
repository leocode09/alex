import 'package:alex/ui/design_system/widgets/app_badge.dart';
import 'package:alex/ui/design_system/widgets/app_empty_state.dart';
import 'package:alex/ui/design_system/widgets/app_panel.dart';
import 'package:alex/ui/design_system/widgets/app_search_field.dart';
import 'package:alex/ui/design_system/widgets/app_stat_tile.dart';
import 'package:alex/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('core design system widgets render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            children: const [
              AppPanel(child: Text('Panel')),
              AppBadge(label: 'Status', tone: AppBadgeTone.accent),
              AppSearchField(hintText: 'Search products...'),
              AppStatTile(
                  label: 'Revenue',
                  value: '\$500',
                  icon: Icons.attach_money_outlined),
              AppEmptyState(icon: Icons.inbox_outlined, title: 'No data'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Panel'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('No data'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
