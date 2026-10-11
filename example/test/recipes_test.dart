import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer_example/recipes.dart';

void main() {
  testWidgets('login returns to the original query and fragment',
      (tester) async {
    await tester.pumpWidget(const RecipesApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Protected account'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in and continue'), findsOneWidget);
    await tester.tap(find.text('Sign in and continue'));
    await tester.pumpAndSettle();
    expect(find.text('Destination: /account?section=orders#recent'),
        findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in and continue'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('login rejects external, malformed and non-allowlisted returns', () {
    for (final value in [
      'https://evil.example/account',
      '//evil.example/account',
      '/login',
      '/account/%FF',
      '/account?bad=%'
    ]) {
      expect(safeReturnLocation(value), '/account');
    }
    expect(safeReturnLocation('/account?section=orders#recent'),
        '/account?section=orders#recent');
  });

  testWidgets('tabs retain drafts and system back targets the selected stack',
      (tester) async {
    await tester.pumpWidget(const RecipesApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retained tabs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open tab 1 detail'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First draft');
    await tester.tap(find.text('Second tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open tab 2 detail'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Second draft');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open tab 2 detail'), findsOneWidget);
    await tester.tap(find.text('First tab'));
    await tester.pumpAndSettle();
    expect(find.text('First draft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dirty editor vetoes back and confirms explicit go',
      (tester) async {
    await tester.pumpWidget(const RecipesApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unsaved form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Draft text');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard your draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Draft text'), findsOneWidget);
    await tester.tap(find.text('Go home safely'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Routing recipes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
