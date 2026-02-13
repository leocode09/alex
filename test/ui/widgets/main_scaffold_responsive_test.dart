import 'package:alex/ui/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSized(
    WidgetTester tester, {
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      const MaterialApp(
        home: MainScaffold(
          currentIndex: 0,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses bottom navigation on compact widths', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSized(tester, size: const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses compact rail on medium widths', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSized(tester, size: const Size(900, 900));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('uses extended rail on large widths', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSized(tester, size: const Size(1280, 900));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
