import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';

void main() {
  RouteDefinerRouter makeRouter(List<RouteGuard> guards,
          {void Function()? onBuild, void Function(RouteFailure)? onError}) =>
      RouteDefinerRouter(
        loadingBuilder: (_) => const Text('Application loader'),
        deniedBuilder: (_, current) => Text('Denied: ${current.state.path}'),
        notFoundBuilder: (_, state) => Text('Missing: ${state.uri}'),
        errorBuilder: (_, failure, retry) => TextButton(
            onPressed: retry, child: Text('Retry: ${failure.state.path}')),
        onError: onError,
        routes: [
          RouteDefiner<void>(
            path: '/',
            guards: guards,
            builder: (_, __) {
              onBuild?.call();
              return const Text('Private content');
            },
          ),
        ],
      );

  testWidgets('one ordered pipeline allows content only after every guard',
      (tester) async {
    final order = <String>[];
    final pending = Completer<RouteDecision>();
    final router = makeRouter([
      (_) {
        order.add('first');
        return const RouteDecision.allow();
      },
      (_) {
        order.add('second');
        return pending.future;
      },
      (_) {
        order.add('third');
        return const RouteDecision.allow();
      },
    ], onBuild: () => order.add('built'));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pumpAndSettle();
    expect(order, ['first', 'second']);
    expect(find.text('Application loader'), findsOneWidget);
    // An unrelated theme rebuild must reuse the existing guard attempt.
    await tester.pumpWidget(MaterialApp.router(
        theme: ThemeData.dark(), routerConfig: router.config));
    await tester.pumpAndSettle();
    expect(order, ['first', 'second']);
    pending.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(order, ['first', 'second', 'third', 'built']);
    expect(find.text('Private content'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('deny prevents later guards and the protected builder',
      (tester) async {
    final router = makeRouter([
      (_) => const RouteDecision.deny(),
      (_) => throw StateError('Later guard must not run'),
    ], onBuild: () => fail('Denied content must not build'));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pumpAndSettle();
    expect(find.text('Denied: /'), findsOneWidget);
    expect(find.text('Private content'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  for (final asynchronous in [false, true]) {
    testWidgets(
        '${asynchronous ? 'async' : 'sync'} errors use application retry',
        (tester) async {
      var failAttempt = true;
      var builds = 0;
      final errors = <RouteFailure>[];
      final router = makeRouter([
        (_) {
          if (failAttempt) {
            failAttempt = false;
            if (asynchronous) return Future.error(StateError('Unavailable'));
            throw StateError('Unavailable');
          }
          return const RouteDecision.allow();
        },
      ], onBuild: () => builds++, onError: errors.add);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();
      expect(errors.single.error, isA<StateError>());
      expect(builds, 0);
      expect(find.text('Application loader'), findsNothing);
      await tester.tap(find.text('Retry: /'));
      await tester.pumpAndSettle();
      expect(find.text('Private content'), findsOneWidget);
      expect(errors, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }

  testWidgets('removed pending guard cannot continue or build its page',
      (tester) async {
    final pending = Completer<RouteDecision>();
    late RouteCancellation cancellation;
    final router = makeRouter([
      (current) {
        cancellation = current.cancellation;
        return pending.future;
      },
      (_) => throw StateError('Cancelled chain continued'),
    ], onBuild: () => fail('Removed content was built'));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pumpAndSettle();
    router.replace('/missing?tag=x#section');
    await tester.pumpAndSettle();
    expect(cancellation.isCancelled, isTrue);
    pending.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(find.text('Missing: /missing?tag=x#section'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
