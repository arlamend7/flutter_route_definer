import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';

RouteDefiner<T> page<T>(String path) => RouteDefiner<T>(
    path: path, builder: (_, state) => Text(state.uri.toString()));

RouteDefinerRouter makeRouter({
  List<RouteDefiner<dynamic>>? routes,
  int historyLimit = 0,
  NavigationDiagnostics? diagnostics,
  Duration? timeout,
}) =>
    RouteDefinerRouter(
      routes: routes ??
          [page<void>('/'), page<int>('/items/:id'), page<void>('/other')],
      loadingBuilder: (_) => const Text('Loading'),
      deniedBuilder: (_, __) => const Text('Denied'),
      notFoundBuilder: (_, __) => const Text('Not found'),
      errorBuilder: (_, __, retry) =>
          TextButton(onPressed: retry, child: const Text('Retry')),
      historyLimit: historyLimit,
      diagnostics: diagnostics,
      resolutionTimeout: timeout,
    );

Future<void> mount(WidgetTester tester, RouteDefinerRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester, RouteDefinerRouter router) async {
  await tester.pumpWidget(const SizedBox());
  router.dispose();
}

List<String> paths(List<RouteSnapshot> stack) =>
    stack.map((route) => route.state.path).toList();

class CountingList extends ListBase<Object?> {
  var reads = 0;
  @override
  int get length => 1;
  @override
  set length(int value) => throw UnsupportedError('Fixed fixture');
  @override
  Object? operator [](int index) {
    reads++;
    return 'metadata';
  }

  @override
  void operator []=(int index, Object? value) =>
      throw UnsupportedError('Fixed fixture');
}

// Exercise removal without relying on Flutter calling onDidRemovePage.
class ObserverOnlyRemovalRouter extends RouteDefinerRouter {
  ObserverOnlyRemovalRouter()
      : super(
          routes: [page<void>('/'), page<int>('/items/:id')],
          loadingBuilder: (_) => const SizedBox(),
          deniedBuilder: (_, __) => const SizedBox(),
          notFoundBuilder: (_, __) => const SizedBox(),
          errorBuilder: (_, __, ___) => const SizedBox(),
          historyLimit: 20,
        );

  @override
  Widget build(BuildContext context) {
    final navigator = super.build(context) as Navigator;
    return Navigator(
      key: navigator.key,
      pages: navigator.pages,
      observers: navigator.observers,
      onDidRemovePage: (_) {},
    );
  }
}

void main() {
  test(
      'disabled diagnostics do not traverse snapshot metadata; cancelled listeners stop capture',
      () async {
    final metadata = CountingList();
    final router = makeRouter(routes: [
      RouteDefiner<void>(
          path: '/',
          data: {'nested': metadata},
          builder: (_, __) => const SizedBox())
    ]);
    router.go('/');
    router.replace('/');
    router.refresh();
    expect(metadata.reads, 0);
    final subscription = router.events.listen((_) {});
    router.go('/');
    expect(metadata.reads, greaterThan(0));
    await subscription.cancel();
    metadata.reads = 0;
    router.go('/');
    expect(metadata.reads, 0);
    router.dispose();
  });

  testWidgets(
      'timeout failures reach event-only observers once and ignore late results',
      (tester) async {
    final pending = Completer<RouteDecision>();
    final events = <NavigationEvent>[];
    final router =
        makeRouter(timeout: const Duration(milliseconds: 50), routes: [
      page<void>('/'),
      RouteDefiner<void>(
          path: '/pending',
          guards: [(_) => pending.future],
          builder: (_, __) => throw StateError('Timed-out page built'))
    ]);
    final subscription = router.events.listen(events.add);
    await mount(tester, router);
    router.go('/pending');
    await tester.pumpAndSettle();
    final failures =
        events.where((e) => e.action == NavigationAction.failure).toList();
    expect(failures, hasLength(1));
    expect(failures.single.failure!.error, isA<TimeoutException>());
    expect(failures.single.guardIndex, 0);
    final count = events.length;
    pending.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(events, hasLength(count));
    expect(router.history, isEmpty);
    unawaited(subscription.cancel());
    await unmount(tester, router);
  }, timeout: const Timeout(Duration(seconds: 10)));
  test(
      'current metadata and retained snapshots have independent read-only collections',
      () {
    final tags = ['original'];
    final definition = RouteDefiner<int>(
        path: '/items/:id',
        data: {'tags': tags},
        builder: (_, __) => const SizedBox());
    final router =
        makeRouter(routes: [page<void>('/'), definition], historyLimit: 5);
    final arguments = {
      'values': [1, 2]
    };
    unawaited(router.push<int>('/items/42?tag=a&tag=b#details',
        arguments: arguments));
    final current = router.currentRoute;
    final capturedStack = router.stack;
    final capturedHistory = router.history;
    expect(current.definition, same(definition));
    expect(current.state.path, '/items/42');
    expect(current.state.uriParams, {'id': '42'});
    expect(current.state.queryParamsAll, {
      'tag': ['a', 'b']
    });
    expect(current.state.queryParams['tag'], anyOf('a', 'b'));
    expect(current.state.fragment, 'details');
    expect(current.state.argumentsAs<Map<String, dynamic>>()['values'], [1, 2]);
    expect(current.data, {
      'tags': ['original']
    });
    expect(() => capturedStack.clear(), throwsUnsupportedError);
    expect(() => capturedHistory.clear(), throwsUnsupportedError);
    expect(() => capturedHistory.last.stack.clear(), throwsUnsupportedError);
    expect(() => current.state.uriParams!.clear(), throwsUnsupportedError);
    expect(() => current.state.queryParamsAll['tag']!.clear(),
        throwsUnsupportedError);
    expect(() => (current.state.arguments as Map)['values'].add(3),
        throwsUnsupportedError);
    expect(
        () => (current.data!['tags'] as List).clear(), throwsUnsupportedError);
    arguments['values']!.add(9);
    tags.add('changed');
    router.go('/missing');
    expect(current.state.arguments, {
      'values': [1, 2]
    });
    expect(capturedHistory.last.destination!.data, {
      'tags': ['original']
    });
    expect(paths(capturedStack), ['/', '/items/42']);
    expect(router.currentRoute.definition, isNull);
    expect(router.currentRoute.state.uriParams, isNull);
    expect(router.history.last.action, NavigationAction.reset);
    router.dispose();
  });

  testWidgets(
      'successful pop updates the stack immediately and records one event',
      (tester) async {
    final router = makeRouter(historyLimit: 20);
    await mount(tester, router);
    final result = router.push<int>('/items/42');
    await tester.pumpAndSettle();
    final pushed = router.history.last;
    expect(pushed.action, NavigationAction.push);
    expect(pushed.source!.state.path, '/');
    expect(paths(pushed.stack), ['/', '/items/42']);
    await router.pop<int>(42);
    // Before pumping the outgoing animation, the managed stack is up to date.
    expect(router.currentRoute.state.path, '/');
    expect(await result, 42);
    final popped = router.history.last;
    expect(popped.action, NavigationAction.pop);
    expect(popped.source!.id, pushed.destination!.id);
    expect(popped.route!.state.path, '/items/42');
    expect(paths(popped.stack), ['/']);
    await tester.pumpAndSettle();
    expect(router.history.last, same(popped));
    expect(router.history.where((e) => e.action == NavigationAction.pop),
        hasLength(1));
    expect(router.history.any((e) => e.action == NavigationAction.remove),
        isFalse);
    await unmount(tester, router);
  });

  testWidgets(
      'removal below the top, replacement and reset retain accurate subjects',
      (tester) async {
    final router = makeRouter(historyLimit: 30);
    await mount(tester, router);
    final removedResult = router.push<int>('/items/1');
    await tester.pumpAndSettle();
    final native = ModalRoute.of(tester.element(find.text('/items/1')))!;
    final replacedResult = router.push<int>('/items/2');
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!.removeRoute(native);
    await tester.pumpAndSettle();
    final removed = router.history.last;
    expect(removed.action, NavigationAction.remove);
    expect(removed.route!.state.path, '/items/1');
    expect(removed.source!.id, removed.destination!.id);
    expect(paths(removed.stack), ['/', '/items/2']);
    expect(await removedResult, isNull);
    expect(router.history.where((e) => e.action == NavigationAction.remove),
        hasLength(1));
    router.replace('/other');
    final replaced = router.history.last;
    expect(replaced.action, NavigationAction.replace);
    expect(replaced.source!.state.path, '/items/2');
    expect(paths(replaced.stack), ['/', '/other']);
    expect(await replacedResult, isNull);
    await tester.pumpAndSettle();
    expect(router.history.last, same(replaced));
    router.go('/');
    final reset = router.history.last;
    await tester.pumpAndSettle();
    expect(reset.action, NavigationAction.reset);
    expect(paths(reset.stack), ['/']);
    expect(router.history.last, same(reset));
    expect(paths(removed.stack), ['/', '/items/2']);
    await unmount(tester, router);
  });

  testWidgets('observer synchronizes removal without the page callback',
      (tester) async {
    final router = ObserverOnlyRemovalRouter();
    await mount(tester, router);
    Object? result = 'pending';
    unawaited(router.push<int>('/items/1').then((value) => result = value));
    await tester.pumpAndSettle();
    final native = ModalRoute.of(tester.element(find.text('/items/1')))!;
    unawaited(router.push<int>('/items/2'));
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!.removeRoute(native);
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(paths(router.stack), ['/', '/items/2']);
    expect(router.history.last.action, NavigationAction.remove);
    expect(router.history.last.route!.state.path, '/items/1');
    final previous = router.history.last;

    unawaited(showDialog<void>(
        context: router.navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Temporary dialog'))));
    await tester.pumpAndSettle();
    final dialog =
        ModalRoute.of(tester.element(find.text('Temporary dialog')))!;
    router.navigatorKey.currentState!.removeRoute(dialog);
    await tester.pumpAndSettle();
    expect(find.text('Temporary dialog'), findsNothing);
    expect(paths(router.stack), ['/', '/items/2']);
    expect(router.history.last, same(previous));
    await unmount(tester, router);
  });

  test(
      'history is optional, bounded and ordered; invalid calls create no events',
      () {
    expect(() => makeRouter(historyLimit: -1), throwsArgumentError);
    final disabled = makeRouter();
    disabled.go('/other');
    expect(disabled.history, isEmpty);
    disabled.dispose();
    final router = makeRouter(historyLimit: 2);
    expect(router.history.single.action, NavigationAction.initialize);
    router.go('/items/1');
    final old = router.history;
    router.replace('/other');
    router.refresh();
    expect(router.history.map((e) => e.action),
        [NavigationAction.replace, NavigationAction.refresh]);
    expect(router.history.map((e) => e.sequence), [3, 4]);
    expect(router.history.every((e) => e.timestamp.isUtc), isTrue);
    expect(old.first.action, NavigationAction.initialize);
    expect(() => router.push<void>('/bad/%'), throwsFormatException);
    expect(() => router.push<void>('/other', arguments: Object()),
        throwsArgumentError);
    expect(router.history.last.sequence, 4);
    router.dispose();
    expect(router.history, isEmpty);
  });

  test(
      'event observation is asynchronous, independent of retention, and closes',
      () async {
    final router = makeRouter();
    final events = <NavigationEvent>[];
    var notifications = 0;
    var closed = false;
    void changed() => notifications++;
    router.addListener(changed);
    final subscription =
        router.events.listen(events.add, onDone: () => closed = true);
    router.go('/items/1');
    router.replace('/other');
    expect(events, isEmpty);
    expect(notifications, 2);
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.action),
        [NavigationAction.reset, NavigationAction.replace]);
    expect(paths(events.first.stack), ['/', '/items/1']);
    expect(router.history, isEmpty);
    router.removeListener(changed);
    router.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(closed, isTrue);
    await subscription.cancel();
  });

  testWidgets('restored configurations are recorded as restore with stable IDs',
      (tester) async {
    final router = makeRouter(historyLimit: 10);
    await mount(tester, router);
    unawaited(router.push<int>('/items/42', arguments: {'version': 1}));
    await tester.pumpAndSettle();
    final saved = router.currentConfiguration;
    await router.setNewRoutePath(RouteStack([
      saved.locations.first,
      RouteLocation(saved.uri,
          id: saved.locations.last.id, arguments: {'version': 2}),
    ]));
    final event = router.history.last;
    expect(event.action, NavigationAction.restore);
    expect(event.source!.id, event.destination!.id);
    expect(event.source!.state.arguments, {'version': 1});
    expect(event.destination!.state.arguments, {'version': 2});
    await tester.pumpAndSettle();
    expect(router.history.last, same(event));
    await unmount(tester, router);
  });

  testWidgets('dialogs and vetoed pops do not create managed stack events',
      (tester) async {
    final router = makeRouter(historyLimit: 10, routes: [
      page<void>('/'),
      RouteDefiner<void>(
          path: '/edit',
          builder: (_, __) =>
              const PopScope<void>(canPop: false, child: Text('Edit')))
    ]);
    await mount(tester, router);
    unawaited(router.push<void>('/edit'));
    await tester.pumpAndSettle();
    final previous = router.history.last;
    await router.pop();
    unawaited(showDialog<void>(
        context: router.navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Dialog'))));
    await tester.pumpAndSettle();
    expect(router.currentRoute.state.path, '/edit');
    expect(paths(router.stack), ['/', '/edit']);
    await router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsNothing);
    expect(router.history.last, same(previous));
    await unmount(tester, router);
  });

  testWidgets('nested routers report their own pages and events',
      (tester) async {
    final child = makeRouter(historyLimit: 10);
    final parent = makeRouter(historyLimit: 10, routes: [
      RouteDefiner<void>(
          path: '/',
          builder: (_, __) =>
              Router<RouteStack>.withConfig(config: child.nestedConfig))
    ]);
    await mount(tester, parent);
    final previous = parent.history.last;
    unawaited(child.push<int>('/items/7'));
    await tester.pumpAndSettle();
    expect(parent.currentRoute.state.path, '/');
    expect(child.currentRoute.state.path, '/items/7');
    expect(parent.history.last, same(previous));
    expect(child.history.last.action, NavigationAction.push);
    await unmount(tester, parent);
    child.dispose();
  });

  testWidgets(
      'guards and redirects record ordered outcomes and the resulting stack',
      (tester) async {
    var protectedBuilds = 0;
    final logs = <String>[];
    final router = makeRouter(
        historyLimit: 30,
        diagnostics: NavigationDiagnostics(logger: logs.add),
        routes: [
          page<void>('/'),
          page<void>('/other'),
          RouteDefiner<void>(
              path: '/private',
              guards: [
                (_) => const RouteDecision.allow(),
                (_) => const RouteDecision.redirect('/other'),
                (_) => throw StateError('Later guard ran'),
              ],
              builder: (_, __) {
                protectedBuilds++;
                return const SizedBox();
              }),
          RouteDefiner<void>(
              path: '/loop',
              guards: [(_) => const RouteDecision.redirect('/loop')],
              builder: (_, __) => throw StateError('Loop page built'))
        ]);
    await mount(tester, router);
    final before = router.history.last.sequence;
    unawaited(router.push<void>('/private'));
    await tester.pumpAndSettle();
    final events = router.history.where((e) => e.sequence > before).toList();
    expect(events.map((e) => e.action), [
      NavigationAction.push,
      NavigationAction.guardResult,
      NavigationAction.guardResult,
      NavigationAction.redirect
    ]);
    expect(events[1].guardIndex, 0);
    expect(events[1].guardOutcome, NavigationGuardOutcome.allow);
    expect(events[2].guardOutcome, NavigationGuardOutcome.redirect);
    expect(events.last.source!.state.path, '/private');
    expect(events.last.destination!.state.path, '/other');
    expect(paths(events.last.stack), ['/', '/other']);
    expect(protectedBuilds, 0);
    router.go('/loop');
    await tester.pumpAndSettle();
    expect(router.history.last.action, NavigationAction.failure);
    expect(router.history.last.failure!.error, isA<RouteRedirectException>());
    expect(
        logs.any((line) => jsonDecode(line)['action'] == 'redirect'), isTrue);
    await unmount(tester, router);
  });

  testWidgets(
      'denials, errors, retry and cancellation never log a false success',
      (tester) async {
    var fails = true;
    final pending = Completer<RouteDecision>();
    final router = makeRouter(historyLimit: 30, routes: [
      page<void>('/'),
      RouteDefiner<void>(
          path: '/denied',
          guards: [(_) => const RouteDecision.deny()],
          builder: (_, __) => throw StateError('Denied page built')),
      RouteDefiner<void>(
          path: '/failure',
          guards: [
            (_) {
              if (fails) {
                fails = false;
                throw StateError('Failure');
              }
              return const RouteDecision.allow();
            }
          ],
          builder: (_, __) => const Text('Recovered')),
      RouteDefiner<void>(
          path: '/pending',
          guards: [(_) => pending.future],
          builder: (_, __) => throw StateError('Cancelled page built'))
    ]);
    await mount(tester, router);
    router.go('/denied');
    await tester.pumpAndSettle();
    expect(router.history.last.guardOutcome, NavigationGuardOutcome.deny);
    expect(router.currentRoute.state.path, '/denied');
    router.go('/failure');
    await tester.pumpAndSettle();
    expect(router.history.last.action, NavigationAction.failure);
    expect(router.history.last.guardIndex, 0);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(router.history.last.guardOutcome, NavigationGuardOutcome.allow);
    expect(find.text('Recovered'), findsOneWidget);
    router.go('/pending');
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    final last = router.history.last;
    pending.complete(const RouteDecision.allow());
    await tester.pumpAndSettle();
    expect(router.history.last, same(last));
    await unmount(tester, router);
  });

  testWidgets(
      'diagnostics redact every route position and exception by default',
      (tester) async {
    final messages = <String>[];
    final router = makeRouter(
        diagnostics: NavigationDiagnostics(logger: messages.add),
        routes: [
          page<void>('/'),
          RouteDefiner<void>(
              path: '/items/:id',
              data: {'private': 'data-secret'},
              guards: [(_) => throw StateError('error-secret')],
              builder: (_, __) => const SizedBox())
        ]);
    await mount(tester, router);
    router.go('/items/path-secret?token=query-secret#fragment-secret',
        arguments: {'token': 'argument-secret'});
    await tester.pumpAndSettle();
    router.go('/unknown-secret?token=another-secret');
    await tester.pumpAndSettle();
    final text = messages.join('\n');
    expect(text, isNot(contains('secret')));
    expect(text, contains('/items/:id'));
    expect(text, contains('StateError'));
    expect(text, contains('<unmatched>'));
    expect(router.history, isEmpty);
    await unmount(tester, router);
  });

  testWidgets(
      'diagnostics allow explicit sensitive fields and tolerate logger errors',
      (tester) async {
    final messages = <String>[];
    final router = makeRouter(
        diagnostics: NavigationDiagnostics(
            logger: messages.add,
            includeParameters: true,
            includeArguments: true,
            includeData: true,
            includeErrorDetails: true),
        routes: [
          page<void>('/'),
          RouteDefiner<void>(
              path: '/items/:id',
              data: {'key': 'custom-data'},
              guards: [(_) => throw StateError('failure-details')],
              builder: (_, __) => const SizedBox())
        ]);
    await mount(tester, router);
    router.go('/items/42?tag=a&tag=b#details', arguments: {'key': 'payload'});
    await tester.pumpAndSettle();
    final last = jsonDecode(messages.last) as Map<String, dynamic>;
    expect(last['action'], 'failure');
    expect(last['route']['pathParameters'], {'id': '42'});
    expect(last['route']['queryParameters'], {
      'tag': ['a', 'b']
    });
    expect(last['route']['fragment'], 'details');
    expect(last['route']['arguments'], contains('payload'));
    expect(last['route']['data'], contains('custom-data'));
    expect(last['error'], contains('failure-details'));
    await unmount(tester, router);
    final throwing = makeRouter(
        diagnostics:
            NavigationDiagnostics(logger: (_) => throw StateError('Logger')));
    await mount(tester, throwing);
    final result = throwing.push<int>('/items/1');
    await tester.pumpAndSettle();
    await throwing.pop<int>(5);
    await tester.pumpAndSettle();
    expect(await result, 5);
    expect(tester.takeException(), isNull);
    await unmount(tester, throwing);
  });
}
