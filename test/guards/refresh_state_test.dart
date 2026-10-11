import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import '../support/router.dart';

void main() {
  for (final guarded in [false, true]) {
    testWidgets('refresh preserves form state, guarded=$guarded',
        (tester) async {
      Completer<RouteDecision>? pending;
      final focus = FocusNode();
      final router = testRouter([
        RouteDefiner<void>(
          path: '/',
          guards: guarded
              ? [(_) => pending?.future ?? const RouteDecision.allow()]
              : [],
          builder: (_, __) => Scaffold(body: TextField(focusNode: focus)),
        ),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep my draft');
      final state = tester.state(find.byType(TextField));
      pending = Completer<RouteDecision>();
      router.refresh();
      await tester.pumpAndSettle();
      if (guarded) {
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Checking access'), findsOneWidget);
        expect(focus.hasFocus, isFalse);
        expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
        pending.complete(const RouteDecision.allow());
        await tester.pumpAndSettle();
      }
      expect(tester.state(find.byType(TextField)), same(state));
      expect(find.text('Keep my draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      focus.dispose();
    });
  }

  testWidgets(
      'changed definitions and restored arguments reset unguarded state',
      (tester) async {
    RouteDefiner<void> page() => RouteDefiner<void>(
        path: '/', builder: (_, __) => const Scaffold(body: TextField()));
    final router = testRouter([page()]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Old definition');
    router.updateRoutes([page()]);
    await tester.pumpAndSettle();
    expect(find.text('Old definition'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Old arguments');
    final location = router.currentConfiguration.locations.single;
    await router.setNewRoutePath(RouteStack([
      RouteLocation(location.uri, id: location.id, arguments: {'new': true}),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Old arguments'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  for (final fails in [false, true]) {
    testWidgets('revalidation discards state on ${fails ? 'error' : 'denial'}',
        (tester) async {
      var attempt = 0;
      final pending = Completer<RouteDecision>();
      final router = testRouter([
        RouteDefiner<void>(
            path: '/',
            guards: [
              (_) {
                attempt++;
                return attempt == 2
                    ? pending.future
                    : const RouteDecision.allow();
              }
            ],
            builder: (_, __) => const Scaffold(body: TextField())),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Private draft');
      router.refresh();
      await tester.pumpAndSettle();
      if (fails) {
        pending.completeError(StateError('Unavailable'));
      } else {
        pending.complete(const RouteDecision.deny());
      }
      await tester.pumpAndSettle();
      expect(find.byType(TextField, skipOffstage: false), findsNothing);
      router.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Private draft'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }

  testWidgets('new refresh cancels old attempt and never reveals late content',
      (tester) async {
    final attempts = <Completer<RouteDecision>>[];
    final router = testRouter([
      RouteDefiner<void>(
          path: '/',
          guards: [
            (_) {
              final pending = Completer<RouteDecision>();
              attempts.add(pending);
              return pending.future;
            }
          ],
          builder: (_, __) => const Text('Secret')),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pumpAndSettle();
    router.refresh();
    await tester.pumpAndSettle();
    attempts.first.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(find.text('Secret'), findsNothing);
    attempts.last.complete(const RouteDecision.deny());
    await tester.pumpAndSettle();
    expect(find.text('Secret', skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
