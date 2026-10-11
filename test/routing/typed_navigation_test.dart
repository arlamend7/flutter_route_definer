import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import '../support/router.dart';

void main() {
  testWidgets('definition navigation infers results and preserves encoded URI',
      (tester) async {
    final picker = RouteDefiner<int>(
        path: '/picker/:id', builder: (_, __) => const Text('Picker'));
    final home =
        RouteDefiner<void>(path: '/', builder: (_, __) => const Text('Home'));
    final router = testRouter([home, picker]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pumpAndSettle();
    final result = router.pushRoute(picker,
        parameters: {'id': 'a/b'},
        queryParameters: {
          'tag': ['a', 'b']
        },
        fragment: 'details',
        arguments: {'x': 1});
    // Static assignment checks the inferred result, without an explicit type argument.
    final Future<int?> typedResult = result;
    await tester.pumpAndSettle();
    expect(router.currentRoute.state.requirePathParameter('id'), 'a/b');
    expect(router.currentRoute.state.queryParamsAll['tag'], ['a', 'b']);
    await router.pop(42);
    await tester.pumpAndSettle();
    expect(await typedResult, 42);
    router.goRoute(picker, parameters: {'id': '7'});
    await tester.pumpAndSettle();
    expect(router.stack, hasLength(2));
    router.replaceRoute(home);
    await tester.pumpAndSettle();
    expect(router.currentRoute.state.path, '/');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  test(
      'invalid, stale and shadowed definitions fail without changing the stack',
      () {
    RouteDefiner<int> page(String path) =>
        RouteDefiner<int>(path: path, builder: (_, __) => const SizedBox());
    final broad = page('/users/:id');
    final specific = page('/users/new');
    final router = testRouter([broad, specific]);
    final before = router.currentRoute.id;
    for (final operation in <void Function()>[
      () {
        router.pushRoute(specific);
      },
      () {
        router.goRoute(specific);
      },
      () {
        router.replaceRoute(specific);
      },
      () {
        router.pushRoute(broad);
      },
      () {
        router.pushRoute(page('/missing'));
      },
    ]) {
      expect(operation, throwsArgumentError);
      expect(router.currentRoute.id, before);
    }
    router.updateRoutes([page('/users/:id')]);
    expect(() => router.pushRoute(broad, parameters: {'id': '1'}),
        throwsArgumentError);
    router.dispose();
  });
}
