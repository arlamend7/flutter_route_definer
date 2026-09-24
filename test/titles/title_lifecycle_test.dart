import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/default_pages.dart' as default_router;
import 'package:route_definer/src/titles/title_observer.dart';

void main() {
  RouteDefinerRouter router({Future<String>? slow}) => RouteDefinerRouter(
        loadingBuilder: (_) => const default_router.LoadingPage(),
        deniedBuilder: (_, __) => const default_router.DeniedPage(),
        notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
        errorBuilder: (_, failure, retry) =>
            default_router.ErrorPage(onRetry: retry),
        appTitle: 'App',
        routes: [
          for (final path in ['/', '/a', '/b'])
            RouteDefiner<void>(
                path: path,
                title: (_) => path,
                builder: (_, __) => const SizedBox()),
          RouteDefiner<void>(
              path: '/slow',
              title: (_) => slow!,
              builder: (_, __) => const SizedBox()),
        ],
      );
  MaterialPageRoute<void> page(String name) => MaterialPageRoute<void>(
      settings: RouteSettings(name: name), builder: (_) => const SizedBox());

  testWidgets(
      'one title callback receives URI state; missing and failed titles use appTitle',
      (tester) async {
    final instance = router();
    instance.updateRoutes([
      RouteDefiner<void>(
          path: '/items/:id',
          title: (state) async =>
              '${state.pathInt('id')} ${state.queryParams['q']} ${state.fragment}',
          builder: (_, __) => const SizedBox()),
      RouteDefiner<void>(
          path: '/empty',
          title: (_) => '',
          builder: (_, __) => const SizedBox()),
      RouteDefiner<void>(
          path: '/failure',
          title: (_) => throw StateError('Title'),
          builder: (_, __) => const SizedBox()),
    ]);
    final titles = <String>[];
    final observer =
        TitleObserver(router: instance, onTitleChanged: titles.add);
    for (final path in [
      '/items/42?q=search#details',
      '/empty',
      '/failure',
      '/missing'
    ]) {
      observer.didPush(page(path), null);
      await tester.pump();
    }
    expect(titles, ['42 search details', 'App', 'App', 'App']);
    observer.dispose();
    instance.dispose();
  });

  testWidgets('late successful titles cannot overwrite a newer page',
      (tester) async {
    final slow = Completer<String>();
    final instance = router(slow: slow.future);
    final titles = <String>[];
    final observer =
        TitleObserver(router: instance, onTitleChanged: titles.add);
    observer.didPush(page('/slow'), null);
    observer.didPush(page('/b'), null);
    await tester.pump();
    slow.complete('Old title');
    await tester.pump();
    expect(titles, ['/b']);
    observer.dispose();
    instance.dispose();
  });

  testWidgets('removing/replacing below the top leaves its title intact',
      (tester) async {
    final instance = router();
    final titles = <String>[];
    final observer =
        TitleObserver(router: instance, onTitleChanged: titles.add);
    final first = page('/a');
    final second = page('/b');
    observer.didPush(first, null);
    observer.didPush(second, first);
    await tester.pump();
    expect(titles.last, '/b');
    final replacement = page('/');
    observer.didReplace(oldRoute: first, newRoute: replacement);
    observer.didRemove(replacement, null);
    await tester.pump();
    expect(titles, ['/b']);
    observer.dispose();
    instance.dispose();
  });

  testWidgets('a stale title failure cannot replace the active title',
      (tester) async {
    final slow = Completer<String>();
    final instance = router(slow: slow.future);
    final titles = <String>[];
    final observer =
        TitleObserver(router: instance, onTitleChanged: titles.add);
    final first = page('/slow');
    final second = page('/b');
    observer.didPush(first, null);
    observer.didPush(second, first);
    await tester.pump();
    slow.completeError(StateError('old request failed'));
    await tester.pump();
    expect(titles, ['/b']);
    observer.dispose();
    instance.dispose();
  });

  testWidgets('dialogs retain the page title and disposal suppresses late work',
      (tester) async {
    final slow = Completer<String>();
    final instance = router(slow: slow.future);
    final titles = <String>[];
    final observer =
        TitleObserver(router: instance, onTitleChanged: titles.add);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      final first = page('/a');
      observer.didPush(first, null);
      observer.didPush(
          DialogRoute<void>(context: context, builder: (_) => const SizedBox()),
          first);
      return const SizedBox();
    })));
    await tester.pump();
    expect(titles, ['/a']);
    observer.didPush(page('/slow'), null);
    observer.dispose();
    slow.complete('Late');
    await tester.pump();
    expect(titles, ['/a']);
    instance.dispose();
  });
  testWidgets(
      'detaching a Navigator suppresses its pending title without explicit disposal',
      (tester) async {
    final slow = Completer<String>();
    final instance = router(slow: slow.future);
    final titles = <String>[];
    final observer =
        TitleObserver(router: instance, onTitleChanged: titles.add);
    await tester.pumpWidget(MaterialApp(
        home: Navigator(
      observers: [observer],
      pages: const [MaterialPage<void>(name: '/slow', child: SizedBox())],
      onDidRemovePage: (_) {},
    )));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    slow.complete('Detached');
    await tester.pump();
    expect(titles, isEmpty);
    observer.dispose();
    instance.dispose();
  });
}
