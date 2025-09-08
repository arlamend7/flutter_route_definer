import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/title_observer.dart';

/// Tests for [TitleObserver] behavior.
void main() {
  setUp(() {
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'App',
        onUnknownRoute: (RouteSettings settings, RouteState state) =>
            MaterialPageRoute(builder: (_) => const Placeholder(), settings: settings),
      ),
      <RouteDefiner>[
        RouteDefiner(
          path: '/withTitle',
          builder: (_, __) => const Placeholder(),
          title: () async => 'Route Title',
        ),
        RouteDefiner(path: '/noTitle', builder: (_, __) => const Placeholder()),
        RouteDefiner(
          path: '/error',
          builder: (_, __) => const Placeholder(),
          title: () async => throw Exception('oops'),
        ),
      ],
    );
  });

  testWidgets('uses route-specific title when available',
      (WidgetTester tester) async {
    String? captured;
    final TitleObserver observer = TitleObserver(appTitle: (String app, String? route) {
      captured = route;
      return '';
    });

    observer.didPush(
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/withTitle'),
          builder: (_) => const Placeholder()),
      null,
    );
    await tester.pump();
    expect(captured, 'Route Title');
  });

  testWidgets('falls back to app title when route has no title',
      (WidgetTester tester) async {
    String? captured;
    final TitleObserver observer = TitleObserver(appTitle: (String app, String? route) {
      captured = route;
      return '';
    });

    observer.didPush(
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/noTitle'),
          builder: (_) => const Placeholder()),
      null,
    );
    await tester.pump();
    expect(captured, isNull);
  });

  testWidgets('didReplace uses new route when provided',
      (WidgetTester tester) async {
    String? captured;
    final TitleObserver observer = TitleObserver(appTitle: (String app, String? route) {
      captured = route;
      return '';
    });
    observer.didReplace(
      newRoute: MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/withTitle'),
          builder: (_) => const Placeholder()),
      oldRoute: null,
    );
    await tester.pump();
    expect(captured, 'Route Title');
  });

  testWidgets('didReplace ignores when newRoute is null',
      (WidgetTester tester) async {
    final TitleObserver observer = TitleObserver(appTitle: (_, __) => '');
    observer.didReplace(newRoute: null, oldRoute: null);
    await tester.pump();
  });

  testWidgets('didPop uses previous route when available',
      (WidgetTester tester) async {
    String? captured;
    final TitleObserver observer = TitleObserver(appTitle: (String app, String? route) {
      captured = route;
      return '';
    });
    observer.didPop(
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/noTitle'),
          builder: (_) => const Placeholder()),
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/withTitle'),
          builder: (_) => const Placeholder()),
    );
    await tester.pump();
    expect(captured, 'Route Title');
  });

  testWidgets('didPop ignores when previousRoute is null',
      (WidgetTester tester) async {
    final TitleObserver observer = TitleObserver(appTitle: (_, __) => '');
    observer.didPop(
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/noTitle'),
          builder: (_) => const Placeholder()),
      null,
    );
    await tester.pump();
  });

  testWidgets('falls back to app title when title builder throws',
      (WidgetTester tester) async {
    bool called = false;
    final TitleObserver observer = TitleObserver(appTitle: (String app, String? route) {
      called = true;
      return '';
    });
    observer.didPush(
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/error'),
          builder: (_) => const Placeholder()),
      null,
    );
    await tester.pump();
    expect(called, isFalse);
  });

  test('defaultTitleGenerator formats titles correctly', () {
    expect(TitleObserver.defaultTitleGenerator('App', 'Home'), 'App | Home');
    expect(TitleObserver.defaultTitleGenerator('App', null), 'App');
  });

  test('updateBrowserTitle stub executes without error', () {
    updateBrowserTitle('Test');
  });
}
