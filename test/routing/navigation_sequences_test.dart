import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import '../support/router.dart';

void main() {
  for (final seed in [7, 42, 20260927]) {
    testWidgets('navigation state machine, seed=$seed', (tester) async {
      final random = Random(seed);
      final pending = <({
        Completer<RouteDecision> completer,
        RouteCancellation cancellation
      })>[];
      var unauthorizedBuilds = 0;
      final allowed = <String>{};
      final router = testRouter([
        RouteDefiner<void>(path: '/', builder: (_, __) => const Text('Home')),
        RouteDefiner<int>(
            path: '/item/:id',
            guards: [
              (current) {
                final completer = Completer<RouteDecision>();
                pending.add(
                    (completer: completer, cancellation: current.cancellation));
                return completer.future.then((decision) {
                  if (!current.cancellation.isCancelled &&
                      decision is AllowNavigation) {
                    allowed.add(current.state.path);
                  }
                  return decision;
                });
              }
            ],
            builder: (_, state) {
              if (!allowed.contains(state.path)) unauthorizedBuilds++;
              return Text(state.path);
            }),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();
      var model = <String>['/'];
      final completions = <String, int>{};
      var serial = 0;
      for (var step = 0; step < 100; step++) {
        final path = '/item/${serial++}';
        switch (random.nextInt(7)) {
          case 0:
            final result = router.push<int>(path);
            final id = router.currentRoute.id;
            completions[id] = 0;
            unawaited(
                result.then((_) => completions[id] = completions[id]! + 1));
            model.add(path);
          case 1:
            router.replace(path);
            model[model.length - 1] = path;
          case 2:
            router.go(path);
            model = ['/', path];
          case 3:
            if (model.length > 1) {
              final index = random.nextInt(model.length);
              router.remove(router.stack[index].id);
              model.removeAt(index);
            }
          case 4:
            router.refresh();
          case 5:
            const parser = RouteDefinerParser();
            final restored = await parser.parseRouteInformation(
                parser.restoreRouteInformation(router.currentConfiguration));
            await router.setNewRoutePath(restored);
          case 6:
            if (model.length > 1) {
              await router.pop<int>(step);
              model.removeLast();
            }
        }
        await tester.pumpAndSettle();
        // Resolve arbitrary attempts after navigation, including cancelled ones.
        for (final attempt in pending.where((p) => !p.completer.isCompleted)) {
          if (random.nextBool()) {
            attempt.completer.complete(random.nextBool()
                ? const RouteDecision.allow()
                : const RouteDecision.deny());
          }
        }
        await tester.pumpAndSettle();
        final stack = router.stack;
        expect(stack.map((s) => s.state.path).toList(), model,
            reason: 'seed=$seed step=$step');
        expect(stack.map((s) => s.id).toSet().length, stack.length);
        final live = stack.map((s) => s.id).toSet();
        for (final completion in completions.entries) {
          expect(completion.value, live.contains(completion.key) ? 0 : 1,
              reason: 'completion seed=$seed step=$step id=${completion.key}');
        }
        expect(unauthorizedBuilds, 0);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      for (final attempt in pending.where((p) => !p.completer.isCompleted)) {
        expect(attempt.cancellation.isCancelled, isTrue);
        attempt.completer.complete(const RouteDecision.allow());
      }
      await tester.pump();
      expect(completions.values, everyElement(1));
      expect(tester.takeException(), isNull);
    });
  }
}
