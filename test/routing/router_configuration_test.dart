import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';

void main() {
  RouteDefinerRouter router(List<RouteDefiner<dynamic>> routes,
          {DefinedRouteFactory? factory}) =>
      RouteDefinerRouter(
        routes: routes,
        loadingBuilder: (_) => const Text('Loading'),
        deniedBuilder: (_, __) => const Text('Denied'),
        notFoundBuilder: (_, state) => Text('Missing ${state.uri}'),
        errorBuilder: (_, __, ___) => const Text('Failure'),
        routeFactory: factory,
        defaultRouteOptions: const RouteOptions(
            maintainState: false, fullscreenDialog: true, requestFocus: false),
      );
  RouteDefiner<void> page(String path) => RouteDefiner<void>(
      path: path, builder: (_, state) => Text(state.uri.toString()));

  test('lookup ignores partial matches and preserves decoded complete state',
      () {
    final instance = router([
      page('/users/:id/edit'),
      page('/users/:id'),
    ]);
    final match = instance.match('/users/jane%2Fdoe?tag=a&tag=b#details',
        arguments: {'source': 'test'});
    expect(match.definition!.path, '/users/:id');
    expect(match.state.requirePathParameter('id'), 'jane/doe');
    expect(match.state.queryParamsAll['tag'], ['a', 'b']);
    expect(match.state.fragment, 'details');
    expect(match.state.arguments, {'source': 'test'});
    final unknown = instance.match('/users');
    expect(unknown.definition, isNull);
    expect(unknown.state.uriParams, isNull);
    instance.dispose();
  });

  testWidgets('unknown partial destination remains above registered ancestors',
      (tester) async {
    final instance = router([page('/'), page('/users/:id/edit')]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: instance.config));
    instance.go('/users/42?tag=a#details');
    await tester.pumpAndSettle();
    expect(instance.currentConfiguration.locations.map((e) => e.uri.toString()),
        ['/', '/users/42?tag=a#details']);
    expect(find.text('Missing /users/42?tag=a#details'), findsOneWidget);
    await instance.pop();
    await tester.pumpAndSettle();
    expect(find.text('/'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    instance.dispose();
  });

  testWidgets(
      'global factory covers typed, unknown and error pages; route overrides win',
      (tester) async {
    final optionsByPath = <String, RouteOptions>{};
    final instance = router([
      page('/'),
      RouteDefiner<int>(
        path: '/picker',
        options: const RouteOptions(maintainState: true),
        builder: (_, __) => const Text('Picker'),
      ),
      RouteDefiner<void>(
        path: '/custom',
        routeFactory: <T>(settings, builder, options) =>
            MaterialPageRoute<T>(settings: settings, builder: builder),
        builder: (_, __) => const Text('Custom'),
      ),
      RouteDefiner<void>(
        path: '/error',
        guards: [(_) => throw StateError('Failed guard')],
        builder: (_, __) => throw StateError('Must not build'),
      ),
    ], factory: <T>(settings, builder, options) {
      optionsByPath[settings.name!] = options;
      return CupertinoPageRoute<T>(
        settings: settings,
        builder: builder,
        maintainState: options.maintainState ?? true,
        fullscreenDialog: options.fullscreenDialog ?? false,
      );
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: instance.config));
    await tester.pumpAndSettle();
    final result = instance.push<int>('/picker');
    await tester.pumpAndSettle();
    final native = ModalRoute.of(tester.element(find.text('Picker')))!;
    expect(native, isA<CupertinoPageRoute<int>>());
    expect(native.settings, isA<Page<int>>());
    expect(optionsByPath['/picker']!.maintainState, isTrue);
    expect(optionsByPath['/picker']!.fullscreenDialog, isTrue);
    expect(optionsByPath['/picker']!.requestFocus, isFalse);
    await instance.pop<int>(7);
    await tester.pumpAndSettle();
    expect(await result, 7);
    for (final path in ['/missing', '/error', '/custom']) {
      instance.go(path);
      await tester.pumpAndSettle();
    }
    expect(optionsByPath.keys,
        containsAll(['/', '/picker', '/missing', '/error']));
    expect(optionsByPath, isNot(contains('/custom')));
    expect(ModalRoute.of(tester.element(find.text('Custom'))),
        isA<MaterialPageRoute<void>>());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    instance.dispose();
  });
}
