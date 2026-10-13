import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/material.dart' as rd;

rd.RouteDefiner<void> home() =>
    rd.RouteDefiner<void>.simple(path: '/', builder: (_) => const Text('Home'));

Future<void> mount(WidgetTester tester, rd.RouteDefinerRouter router) async {
  await tester.pumpWidget(MaterialApp.router(
      routerConfig: router.config, restorationScopeId: 'app'));
  await tester.pumpAndSettle();
}

Future<void> close(WidgetTester tester, rd.RouteDefinerRouter router) async {
  await tester.pumpWidget(const SizedBox());
  router.dispose();
}

void main() {
  test('query helpers reject malformed and repeated scalars', () {
    final state = rd.RouteState(Uri.parse('/?n=-12&b=false&tag=a&tag=b'));
    expect(state.queryInt('n'), -12);
    expect(state.queryBool('b'), false);
    expect(state.queryInt('missing'), isNull);
    expect(state.queryBool('missing'), isNull);
    expect(state.queryValues('missing'), isEmpty);
    expect(state.queryValues('tag'), ['a', 'b']);
    expect(() => state.queryValues('tag').add('c'), throwsUnsupportedError);
    for (final query in [
      'n=',
      'n=1&n=2',
      'n=0x12',
      'n=%201',
      'n=1.5',
      'n=1%0A'
    ]) {
      expect(() => rd.RouteState(Uri.parse('/?$query')).queryInt('n'),
          throwsFormatException);
    }
    for (final query in ['b=', 'b=TRUE', 'b=1', 'b=true&b=false']) {
      expect(() => rd.RouteState(Uri.parse('/?$query')).queryBool('b'),
          throwsFormatException);
    }
    expect(rd.RouteState(Uri.parse('/?b=true')).queryBool('b'), isTrue);
  });

  test('callback codec round trips custom payloads through history', () async {
    final codec = rd.RouteArgumentsCodec.callbacks(
      encode: (value) => value == null
          ? null
          : {'date': (value as DateTime).toIso8601String()},
      decode: (value) => value == null
          ? null
          : DateTime.parse((value as Map)['date'] as String),
    );
    final parser = rd.RouteDefinerParser(argumentsCodec: codec);
    final date = DateTime.utc(2026, 1, 1);
    final state = rd.RouteStack(
        [rd.RouteLocation(Uri.parse('/'), id: '1', arguments: date)]);
    final restored = await parser
        .parseRouteInformation(parser.restoreRouteInformation(state));
    expect(restored.locations.single.arguments, date);
    final invalid = rd.RouteArgumentsCodec.callbacks(
        encode: (_) => Object(), decode: (x) => x);
    expect(() => invalid.encode(null), throwsArgumentError);
    final broken = rd.RouteDefinerParser(
        argumentsCodec: rd.RouteArgumentsCodec.callbacks(
            encode: (x) => x,
            decode: (_) => throw const FormatException('bad payload')));
    final fallback = await broken
        .parseRouteInformation(parser.restoreRouteInformation(state));
    expect(fallback.uri.path, '/');
    expect(fallback.locations.single.arguments, isNull);
  });

  final factories = <String, rd.DefinedPageRouteFactory>{
    'material': rd.RouteFactories.material,
    'cupertino': rd.RouteFactories.cupertino,
    'none': rd.RouteFactories.noTransition,
    'custom': rd.RouteFactories.transitions(
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 20)),
  };
  for (final factory in factories.entries) {
    testWidgets(
        '${factory.key} keeps settings, typed results, refresh and restoration',
        (tester) async {
      final picker = rd.RouteDefiner<int>.simple(
          path: '/picker',
          pageRouteFactory: factory.value,
          builder: (_) => const Scaffold(body: TextField()));
      final router = rd.createMaterialRouter(
          routes: [home(), picker], restorationScopeId: 'nav');
      await mount(tester, router);
      final Future<int?> result = router.pushRoute(picker, arguments: {'a': 1});
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TextField));
      final route = ModalRoute.of(context)!;
      expect(route.settings, isA<Page<int>>());
      expect(route.settings.arguments, {'a': 1});
      expect((route.settings as Page).restorationId, isNotNull);
      expect(rd.RouteDefinerRouter.of(context), same(router));
      await tester.enterText(find.byType(TextField), 'draft');
      router.refresh();
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsOneWidget);
      await tester.restartAndRestore();
      await tester.pumpAndSettle();
      expect(router.currentRoute.state.path, '/picker');
      await router.pop(7);
      await tester.pumpAndSettle();
      expect(await result, 7);
      await close(tester, router);
    });
  }

  test('factory presets forward options and reject negative durations', () {
    for (final factory in factories.values) {
      const settings = RouteSettings(name: '/x');
      final route = factory.call<int>(
          settings,
          (_) => const SizedBox(),
          const rd.RouteOptions(
              maintainState: false,
              fullscreenDialog: true,
              allowSnapshotting: false,
              barrierDismissible: true,
              requestFocus: false));
      expect(route.settings, same(settings));
      expect(route.maintainState, false);
      expect(route.fullscreenDialog, true);
      expect(route.allowSnapshotting, false);
      expect(route.barrierDismissible, true);
      expect(route.requestFocus, false);
      if (route is PageRouteBuilder<int> &&
          route.transitionDuration == Duration.zero) {
        expect(route.reverseTransitionDuration, Duration.zero);
      }
    }
    expect(
        () => rd.RouteFactories.transitions(
            transitionsBuilder: (_, __, ___, child) => child,
            transitionDuration: const Duration(milliseconds: -1)),
        throwsArgumentError);
  });

  testWidgets('defaults cover loading, denied, missing and error with retry',
      (tester) async {
    final pending = Completer<rd.RouteDecision>();
    var fail = true;
    final router = rd.createMaterialRouter(routes: [
      home(),
      rd.RouteDefiner<void>.simple(
          path: '/protected',
          builder: (_) => const Text('Secret'),
          guards: [(_) => pending.future]),
      rd.RouteDefiner<void>.simple(
          path: '/error',
          builder: (_) => const Text('Recovered'),
          guards: [
            (_) {
              if (fail) throw StateError('failure');
              return const rd.RouteDecision.allow();
            }
          ]),
    ]);
    await mount(tester, router);
    router.go('/protected');
    await tester.pumpAndSettle();
    expect(find.byType(rd.LoadingPage), findsOneWidget);
    pending.complete(const rd.RouteDecision.deny());
    await tester.pumpAndSettle();
    expect(find.byType(rd.DeniedPage), findsOneWidget);
    router.go('/missing');
    await tester.pumpAndSettle();
    expect(find.byType(rd.NotFoundPage), findsOneWidget);
    router.go('/error');
    await tester.pumpAndSettle();
    expect(find.byType(rd.ErrorPage), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    await close(tester, router);
  });

  testWidgets(
      'redirect constructor follows guards, cancellation and loop detection',
      (tester) async {
    final pending = Completer<String>();
    var called = false;
    final router = rd.createMaterialRouter(routes: [
      home(),
      rd.RouteDefiner<void>.redirect(path: '/old', redirect: (_) => '/new'),
      rd.RouteDefiner<void>.simple(
          path: '/new', builder: (_) => const Text('New')),
      rd.RouteDefiner<void>.redirect(
          path: '/blocked',
          guards: [(_) => const rd.RouteDecision.deny()],
          redirect: (_) {
            called = true;
            return '/new';
          }),
      rd.RouteDefiner<void>.redirect(
          path: '/slow', redirect: (_) => pending.future),
      rd.RouteDefiner<void>.redirect(path: '/loop', redirect: (_) => '/loop'),
    ]);
    await mount(tester, router);
    router.go('/old');
    await tester.pumpAndSettle();
    expect(router.currentRoute.state.path, '/new');
    router.go('/blocked');
    await tester.pumpAndSettle();
    expect(called, false);
    expect(find.byType(rd.DeniedPage), findsOneWidget);
    router.go('/slow');
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    pending.complete('/new');
    await tester.pumpAndSettle();
    expect(router.currentRoute.state.path, '/');
    router.go('/loop');
    await tester.pumpAndSettle();
    expect(find.byType(rd.ErrorPage), findsOneWidget);
    await close(tester, router);
  });

  testWidgets(
      'lookup returns nearest nested router and diagnoses missing scope',
      (tester) async {
    late final rd.RouteDefinerRouter child;
    child = rd.createMaterialRouter(routes: [
      rd.RouteDefiner<void>.simple(
          path: '/',
          builder: (context) {
            expect(rd.RouteDefinerRouter.of(context), same(child));
            return const Text('Child');
          })
    ]);
    late final rd.RouteDefinerRouter parent;
    parent = rd.createMaterialRouter(routes: [
      rd.RouteDefiner<void>.simple(
          path: '/',
          builder: (context) {
            expect(rd.RouteDefinerRouter.of(context), same(parent));
            return Router(routerDelegate: child);
          })
    ]);
    await mount(tester, parent);
    expect(find.text('Child'), findsOneWidget);
    await tester.pumpWidget(Builder(builder: (context) {
      expect(rd.RouteDefinerRouter.maybeOf(context), isNull);
      expect(() => rd.RouteDefinerRouter.of(context), throwsFlutterError);
      return const SizedBox();
    }));
    parent.dispose();
    child.dispose();
  });

  test('page factories reject copied settings and ambiguous configuration', () {
    PageRoute<T> bad<T>(RouteSettings settings, WidgetBuilder builder,
            rd.RouteOptions options) =>
        MaterialPageRoute<T>(
            builder: builder, settings: RouteSettings(name: settings.name));
    expect(
        () => rd.RouteDefiner<void>.simple(
            path: '/',
            builder: (_) => const SizedBox(),
            routeFactory: rd.RouteFactories.material,
            pageRouteFactory: bad),
        throwsArgumentError);
    expect(
        () => rd.createMaterialRouter(
            routes: [home()],
            routeFactory: rd.RouteFactories.material,
            pageRouteFactory: bad),
        throwsArgumentError);
  });

  testWidgets('definition factories override either default and merge options',
      (tester) async {
    for (final legacy in [false, true]) {
      final picker = rd.RouteDefiner<int>.simple(
        path: '/picker',
        builder: (_) => const Text('Picker'),
        routeFactory: legacy ? rd.RouteFactories.noTransition : null,
        pageRouteFactory: legacy ? null : rd.RouteFactories.noTransition,
        options: const rd.RouteOptions(fullscreenDialog: true),
      );
      final router = rd.createMaterialRouter(
        routes: [home(), picker],
        routeFactory: legacy ? null : rd.RouteFactories.material,
        pageRouteFactory: legacy ? rd.RouteFactories.material : null,
        defaultRouteOptions: const rd.RouteOptions(allowSnapshotting: false),
        notFoundBuilder: (_, state) => Text('Custom missing: ${state.path}'),
      );
      await mount(tester, router);
      final result = router.pushRoute(picker);
      await tester.pumpAndSettle();
      final route =
          ModalRoute.of(tester.element(find.text('Picker')))! as PageRoute<int>;
      expect(route, isA<PageRouteBuilder<int>>());
      expect(route.transitionDuration, Duration.zero);
      expect(route.fullscreenDialog, true);
      expect(route.allowSnapshotting, false);
      await router.pop(9);
      await tester.pumpAndSettle();
      expect(await result, 9);
      router.go('/absent');
      await tester.pumpAndSettle();
      expect(find.text('Custom missing: /absent'), findsOneWidget);
      await close(tester, router);
    }
  });

  testWidgets('invalid page factory reports settings contract before install',
      (tester) async {
    final router = rd.createMaterialRouter(
        routes: [home()],
        pageRouteFactory: <T>(settings, builder, options) =>
            MaterialPageRoute<T>(builder: builder));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    expect(
        tester.takeException(),
        isA<FlutterError>().having(
            (error) => error.toString(), 'message', contains('must preserve')));
    await close(tester, router);
  });
}
