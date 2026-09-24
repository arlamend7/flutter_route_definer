import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/default_pages.dart' as default_router;

RouteDefiner<T> page<T>(String path) => RouteDefiner<T>(
      path: path,
      builder: (_, state) => Text(state.uri.toString()),
    );

RouteDefinerRouter makeRouter(List<RouteDefiner<dynamic>> routes,
        {String initialRoute = '/',
        int redirectLimit = 8,
        Duration? timeout,
        void Function(RouteFailure)? onError,
        Listenable? refresh}) =>
    RouteDefinerRouter(
      loadingBuilder: (_) => const default_router.LoadingPage(),
      deniedBuilder: (_, __) => const default_router.DeniedPage(),
      errorBuilder: (_, failure, retry) =>
          default_router.ErrorPage(onRetry: retry),
      routes: routes,
      refreshListenable: refresh,
      restorationScopeId: 'navigator',
      initialRoute: initialRoute,
      redirectLimit: redirectLimit,
      appTitle: 'Test',
      resolutionTimeout: timeout,
      onError: onError,
      notFoundBuilder: (_, state) => Text('Unknown: ${state.path}'),
    );

Future<void> mount(WidgetTester tester, RouteDefinerRouter router) async {
  await tester.pumpWidget(MaterialApp.router(
      routerConfig: router.config, restorationScopeId: 'app'));
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester, RouteDefinerRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
}

void main() {
  testWidgets('typed pages return pop results and preserve the lower page',
      (tester) async {
    final router = makeRouter([page<void>('/'), page<int>('/pick')]);
    await mount(tester, router);
    final root = router.currentConfiguration.locations.first.id;
    final result = router.push<int>('/pick');
    await tester.pumpAndSettle();
    expect(find.text('/pick'), findsOneWidget);
    expect(router.currentConfiguration.locations.first.id, root);
    await router.pop<int>(42);
    await tester.pumpAndSettle();
    expect(await result, 42);
    expect(router.currentConfiguration.uri.path, '/');
    expect(find.text('/'), findsOneWidget);
    await unmount(tester, router);
  });

  testWidgets('go builds registered ancestors and retains complete URI',
      (tester) async {
    final router = makeRouter([
      page<void>('/'),
      page<void>('/users'),
      page<void>('/users/:id/edit'),
    ]);
    await mount(tester, router);
    router.go('/users/jane%20doe/edit?tag=a&tag=b#section');
    await tester.pumpAndSettle();
    expect(router.currentConfiguration.locations.map((e) => e.uri.path),
        ['/', '/users', '/users/jane%20doe/edit']);
    expect(
        router.currentConfiguration.uri.queryParametersAll['tag'], ['a', 'b']);
    expect(router.currentConfiguration.uri.fragment, 'section');
    await router.pop();
    await tester.pumpAndSettle();
    expect(find.text('/users'), findsOneWidget);
    await unmount(tester, router);
  });

  testWidgets('replacement and stack reset finish pending results',
      (tester) async {
    final router =
        makeRouter([page<void>('/'), page<int>('/pick'), page<void>('/next')]);
    await mount(tester, router);
    final replaced = router.push<int>('/pick');
    await tester.pumpAndSettle();
    router.replace('/next');
    await tester.pumpAndSettle();
    expect(await replaced, isNull);
    final cleared = router.push<int>('/pick');
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    expect(await cleared, isNull);
    expect(router.currentConfiguration.locations, hasLength(1));
    await unmount(tester, router);
  });

  testWidgets('PopScope veto and dialogs are respected', (tester) async {
    var vetoes = 0;
    final router = makeRouter([
      page<void>('/'),
      RouteDefiner<int>(
          path: '/edit',
          builder: (_, __) => PopScope<int>(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (!didPop) vetoes++;
                },
                child: const Text('Editor'),
              )),
    ]);
    await mount(tester, router);
    unawaited(router.push<int>('/edit'));
    await tester.pumpAndSettle();
    await router.pop<int>(7);
    await tester.pumpAndSettle();
    expect(vetoes, 1);
    expect(router.currentConfiguration.uri.path, '/edit');
    unawaited(showDialog<void>(
        context: router.navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Dialog'))));
    await tester.pumpAndSettle();
    await router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsNothing);
    expect(find.text('Editor'), findsOneWidget);
    await unmount(tester, router);
  });

  testWidgets('redirect is terminal and loops become recoverable failures',
      (tester) async {
    var forbidden = 0;
    final errors = <RouteFailure>[];
    final router = makeRouter([
      page<void>('/'),
      page<void>('/login'),
      RouteDefiner<void>(
          path: '/private',
          guards: [
            (_) => const RouteDecision.redirect('/login'),
            (_) {
              forbidden++;
              return const RouteDecision.allow();
            },
          ],
          builder: (_, __) {
            forbidden++;
            return const Text('Private');
          }),
      RouteDefiner<void>(
          path: '/loop',
          guards: [
            (_) => const RouteDecision.redirect('/loop'),
          ],
          builder: (_, __) => const Text('Loop')),
    ], onError: errors.add);
    await mount(tester, router);
    router.go('/private');
    await tester.pumpAndSettle();
    expect(find.text('/login'), findsOneWidget);
    expect(forbidden, 0);
    router.go('/loop');
    await tester.pumpAndSettle();
    expect(find.text('Unable to open this page'), findsOneWidget);
    expect(errors.single.error, isA<RouteRedirectException>());
    expect(tester.takeException(), isNull);
    await unmount(tester, router);
  });

  for (final loop in [true, false]) {
    testWidgets(
        'retry restarts ${loop ? 'loop' : 'limit'} failures with a fresh trace',
        (tester) async {
      var recover = false;
      var calls = 0;
      final errors = <RouteFailure>[];
      final router = makeRouter([
        RouteDefiner<void>(
          path: '/:step',
          guards: [
            (current) {
              calls++;
              final step = current.state.pathInt('step');
              if (recover && step >= 2) return const RouteDecision.allow();
              return RouteDecision.redirect(
                  '/${loop ? (recover ? 2 : step) : step + 1}');
            },
          ],
          builder: (_, state) => Text('Ready: ${state.path}'),
        ),
      ], initialRoute: '/0', redirectLimit: 1, onError: errors.add);
      await mount(tester, router);
      expect(errors.single.error, isA<RouteRedirectException>());
      final beforeRetry = calls;
      // An unchanged application still gets a bounded, reported failure.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(beforeRetry));
      expect(errors, hasLength(2));
      recover = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ready:'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(errors, hasLength(2));
      expect(tester.takeException(), isNull);
      await unmount(tester, router);
    });
  }

  testWidgets('failures can retry and refresh rechecks authorization',
      (tester) async {
    var calls = 0;
    var authorized = true;
    final refresh = ChangeNotifier();
    final router = makeRouter([
      RouteDefiner<void>(
          path: '/',
          guards: [
            (_) {
              if (++calls == 1) throw StateError('offline');
              return authorized
                  ? const RouteDecision.allow()
                  : const RouteDecision.deny();
            }
          ],
          builder: (_, __) => const Text('Private')),
    ], refresh: refresh);
    await mount(tester, router);
    expect(find.text('Unable to open this page'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Private'), findsOneWidget);
    expect(calls, 2);
    authorized = false;
    refresh.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Private'), findsNothing);
    expect(calls, 3);
    await unmount(tester, router);
    refresh.notifyListeners(); // Disposed router has detached its listener.
    refresh.dispose();
  });

  testWidgets('timeout cancels checks and ignores a late authorization',
      (tester) async {
    final pending = Completer<RouteDecision>();
    CurrentRoute? current;
    var laterChecks = 0;
    final router = makeRouter([
      RouteDefiner<void>(
          path: '/',
          guards: [
            (route) {
              current = route;
              return pending.future;
            },
            (_) {
              laterChecks++;
              return const RouteDecision.allow();
            }
          ],
          builder: (_, __) => const Text('Private')),
    ], timeout: const Duration(seconds: 2));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Unable to open this page'), findsOneWidget);
    expect(current!.cancellation.isCancelled, isTrue);
    pending.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(laterChecks, 0);
    expect(find.text('Private'), findsNothing);
    await unmount(tester, router);
  });

  testWidgets('history restores page identity and JSON arguments',
      (tester) async {
    final router = makeRouter([page<void>('/'), page<int>('/pick')]);
    await mount(tester, router);
    unawaited(router.push<int>('/pick?x=1', arguments: {'id': 3}));
    await tester.pumpAndSettle();
    const parser = RouteDefinerParser();
    final saved = parser.restoreRouteInformation(router.currentConfiguration);
    final previousId = router.currentConfiguration.locations.last.id;
    await router.pop();
    await tester.pumpAndSettle();
    await router.setNewRoutePath(await parser.parseRouteInformation(saved));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration.locations.last.id, previousId);
    expect(router.currentConfiguration.locations.last.arguments, {'id': 3});
    expect(find.text('/pick?x=1'), findsOneWidget);
    await unmount(tester, router);
  });

  testWidgets('Router restoration survives restart', (tester) async {
    final router = makeRouter([page<void>('/'), page<int>('/pick')]);
    await mount(tester, router);
    unawaited(router.push<int>('/pick?x=1', arguments: {'id': 3}));
    await tester.pumpAndSettle();
    final restoration = await tester.getRestorationData();
    router.go('/');
    await tester.pumpAndSettle();
    await tester.restoreFrom(restoration);
    await tester.pumpAndSettle();
    expect(router.currentConfiguration.uri.toString(), '/pick?x=1');
    expect(router.currentConfiguration.locations.last.arguments, {'id': 3});
    await unmount(tester, router);
  });

  testWidgets('Cupertino page factory preserves typed results', (tester) async {
    final router = makeRouter([
      page<void>('/'),
      RouteDefiner<int>(
          path: '/pick',
          builder: (_, __) => const Text('Pick'),
          routeFactory: <T>(settings, builder, options) =>
              CupertinoPageRoute<T>(
                settings: settings,
                builder: builder,
                fullscreenDialog: options.fullscreenDialog ?? false,
              )),
    ]);
    await mount(tester, router);
    final result = router.push<int>('/pick');
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!.pop<int>(6);
    await tester.pumpAndSettle();
    expect(await result, 6);
    await unmount(tester, router);
  });

  test('independent routers and immutable definitions prevent shared state',
      () {
    final first = makeRouter([page<void>('/')]);
    final second = makeRouter([page<void>('/other')], initialRoute: '/other');
    expect(first.match('/other').definition, isNull);
    expect(second.match('/').definition, isNull);
    expect(() => first.routes.clear(), throwsUnsupportedError);
    first.dispose();
    second.dispose();
  });

  test('corrupt history falls back to the visible URI', () async {
    const parser = RouteDefinerParser();
    final stack = await parser.parseRouteInformation(RouteInformation(
      uri: Uri.parse('/visible'),
      state: {
        'route_definer': 3,
        'stack': [false]
      },
    ));
    expect(stack.uri.path, '/visible');
    expect(stack.locations.single.id, isNull);
  });

  test('non-serializable Router arguments fail before navigation', () {
    final router = makeRouter([page<void>('/')]);
    expect(
        () => router.push<void>('/', arguments: Object()), throwsArgumentError);
    expect(router.currentConfiguration.locations, hasLength(1));
    router.dispose();
  });
  testWidgets('updating definitions changes the mounted page and its guards',
      (tester) async {
    var rechecks = 0;
    final router = makeRouter([page<void>('/')]);
    await mount(tester, router);
    router.updateRoutes([
      RouteDefiner<void>(
          path: '/',
          guards: [
            (_) {
              rechecks++;
              return const RouteDecision.allow();
            }
          ],
          builder: (_, __) => const Text('Updated'))
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget);
    expect(rechecks, 1);
    await unmount(tester, router);
  });

  testWidgets('a malformed incoming platform URI renders a controlled error',
      (tester) async {
    final errors = <RouteFailure>[];
    final router = makeRouter([page<void>('/')], onError: errors.add);
    await mount(tester, router);
    await router
        .setNewRoutePath(RouteStack([RouteLocation(Uri.parse('/%FF'))]));
    await tester.pumpAndSettle();
    expect(find.text('Unable to open this page'), findsOneWidget);
    expect(errors.single.error, isA<FormatException>());
    expect(tester.takeException(), isNull);
    await unmount(tester, router);
  });

  testWidgets('covered checks cancel and restart only on return',
      (tester) async {
    final attempts = <Completer<RouteDecision>>[];
    final tokens = <RouteCancellation>[];
    final router = makeRouter([
      page<void>('/'),
      page<void>('/cover'),
      RouteDefiner<void>(
          path: '/pending',
          guards: [
            (current) {
              tokens.add(current.cancellation);
              final attempt = Completer<RouteDecision>();
              attempts.add(attempt);
              return attempt.future;
            }
          ],
          builder: (_, __) => const Text('Private')),
    ]);
    await mount(tester, router);
    unawaited(router.push<void>('/pending'));
    await tester.pumpAndSettle();
    unawaited(router.push<void>('/cover'));
    await tester.pumpAndSettle();
    expect(tokens.single.isCancelled, isTrue);
    attempts.single.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(find.text('Private', skipOffstage: false), findsNothing);
    await router.pop();
    await tester.pumpAndSettle();
    expect(attempts, hasLength(2));
    attempts.last.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(find.text('Private'), findsOneWidget);
    await unmount(tester, router);
  });

  testWidgets('unknown page results complete normally', (tester) async {
    final router = makeRouter([page<void>('/')]);
    await mount(tester, router);
    final result = router.push<String>('/unknown');
    await tester.pumpAndSettle();
    await router.pop<String>('returned');
    await tester.pumpAndSettle();
    expect(await result, 'returned');
    await unmount(tester, router);
  });
  testWidgets('nested Router back priority affects only its independent stack',
      (tester) async {
    late final RouteDefinerRouter child;
    final parent = makeRouter([
      RouteDefiner<void>(
          path: '/',
          builder: (_, __) =>
              Router<RouteStack>.withConfig(config: child.nestedConfig))
    ]);
    final dispatcher =
        parent.config.backButtonDispatcher!.createChildBackButtonDispatcher();
    child = RouteDefinerRouter(
        loadingBuilder: (_) => const default_router.LoadingPage(),
        deniedBuilder: (_, __) => const default_router.DeniedPage(),
        notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
        errorBuilder: (_, failure, retry) =>
            default_router.ErrorPage(onRetry: retry),
        initialRoute: '/child',
        appTitle: 'Child',
        routes: [page<void>('/child'), page<void>('/detail')],
        backButtonDispatcher: dispatcher);
    await mount(tester, parent);
    dispatcher.takePriority();
    unawaited(child.push<void>('/detail'));
    await tester.pumpAndSettle();
    expect(find.text('/detail'), findsOneWidget);
    expect(parent.currentConfiguration.uri.path, '/');
    expect(
        await parent.config.backButtonDispatcher!
            .invokeCallback(Future.value(false)),
        isTrue);
    await tester.pumpAndSettle();
    expect(child.currentConfiguration.uri.path, '/child');
    expect(parent.currentConfiguration.uri.path, '/');
    await unmount(tester, parent);
    child.dispose();
  });

  testWidgets('registry refresh rechecks access', (tester) async {
    final router = makeRouter([page<void>('/')]);
    await mount(tester, router);
    router.updateRoutes([
      RouteDefiner<void>(
          path: '/',
          guards: [(_) => const RouteDecision.deny()],
          builder: (_, __) => const Text('Private'))
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Private'), findsNothing);
    await unmount(tester, router);
  });

  testWidgets('removing a page completes its pending library push',
      (tester) async {
    final router = makeRouter([page<void>('/'), page<int>('/pick')]);
    await mount(tester, router);
    final result = router.push<int>('/pick');
    await tester.pumpAndSettle();
    expect(router.remove(router.currentRoute.id), isTrue);
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(router.currentConfiguration.locations, hasLength(1));
    await unmount(tester, router);
  });
  testWidgets(
      'restored argument changes recheck a reused page without losing its result',
      (tester) async {
    final checked = <Object?>[];
    final titled = <Object?>[];
    final router = makeRouter([
      page<void>('/'),
      RouteDefiner<int>(
          path: '/item',
          title: (state) {
            titled.add(state.arguments);
            return 'Item: ${state.arguments}';
          },
          guards: [
            (current) {
              checked.add(current.state.arguments);
              return const RouteDecision.allow();
            }
          ],
          builder: (_, state) => Text('Arguments: ${state.arguments}'))
    ]);
    await mount(tester, router);
    final result = router.push<int>('/item', arguments: 'before');
    await tester.pumpAndSettle();
    final previous = router.currentConfiguration;
    await router.setNewRoutePath(RouteStack([
      previous.locations.first,
      RouteLocation(previous.uri,
          id: previous.locations.last.id, arguments: 'after'),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Arguments: after'), findsOneWidget);
    expect(checked, ['before', 'after']);
    expect(titled.last, 'after');
    expect(router.currentConfiguration.locations.last.id,
        previous.locations.last.id);
    await router.pop<int>(9);
    await tester.pumpAndSettle();
    expect(await result, 9);
    await unmount(tester, router);
  });
}
