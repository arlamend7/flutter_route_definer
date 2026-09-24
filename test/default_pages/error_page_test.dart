import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/default_pages.dart' as default_router;

void main() {
  testWidgets('optional error page supports localized text and keyboard retry',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
        home: default_router.ErrorPage(
      onRetry: () => retries++,
      message: 'Could not load',
      retryLabel: 'Try again',
    )));
    expect(find.text('Could not load'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    // Focus the retry control as a keyboard user would.
    Focus.of(tester.element(find.text('Try again'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(retries, 3);
  });
}
