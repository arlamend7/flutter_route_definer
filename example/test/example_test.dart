import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer_example/main.dart';

void main() {
  testWidgets('runnable example signs in, returns a result and retries',
      (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open guarded account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open item and return a typed result'));
    await tester.pumpAndSettle();
    expect(find.text('Item 42'), findsOneWidget);
    await tester.tap(find.byTooltip('Inspect navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Definition: /items/:id'), findsOneWidget);
    expect(find.text('Path parameters: {id: 42}'), findsOneWidget);
    expect(find.text('Custom data: {section: catalog}'), findsOneWidget);
    expect(find.text('Stack (bottom to top)'), findsOneWidget);
    await tester.tap(find.byTooltip('Close inspector'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose this item'));
    await tester.pumpAndSettle();
    expect(find.text('Selected item 42'), findsOneWidget);
    await tester.tap(find.text('Recover from a guard error'));
    await tester.pumpAndSettle();
    expect(find.text('Navigation failed'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });
}
