import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';

void main() {
  setUp(() {
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'App',
        onUnknownRoute: (settings, state) =>
            MaterialPageRoute(builder: (_) => const Placeholder(), settings: settings),
      ),
      [
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

  testWidgets('uses route-specific title when available', (tester) async {
    String? captured;
    final observer = TitleObserver(appTitle: (app, route) {
      captured = route;
      return '';
    });

    observer.didPush(
      MaterialPageRoute(settings: const RouteSettings(name: '/withTitle'), builder: (_) => const Placeholder()),
      null,
    );
    await tester.pump();
    expect(captured, 'Route Title');
  });

  testWidgets('falls back to app title when route has no title', (tester) async {
    String? captured;
    final observer = TitleObserver(appTitle: (app, route) {
      captured = route;
      return '';
    });

    observer.didPush(
      MaterialPageRoute(settings: const RouteSettings(name: '/noTitle'), builder: (_) => const Placeholder()),
      null,
    );
    await tester.pump();
    expect(captured, isNull);
  });

  testWidgets('didReplace uses new route when provided', (tester) async {
    String? captured;
    final observer = TitleObserver(appTitle: (app, route) {
      captured = route;
      return '';
    });
    observer.didReplace(
      newRoute: MaterialPageRoute(
          settings: const RouteSettings(name: '/withTitle'),
          builder: (_) => const Placeholder()),
      oldRoute: null,
    );
    await tester.pump();
    expect(captured, 'Route Title');
  });

  testWidgets('didReplace ignores when newRoute is null', (tester) async {
    final observer = TitleObserver(appTitle: (_, __) => '');
    observer.didReplace(newRoute: null, oldRoute: null);
    await tester.pump();
  });

  testWidgets('didPop uses previous route when available', (tester) async {
    String? captured;
    final observer = TitleObserver(appTitle: (app, route) {
      captured = route;
      return '';
    });
    observer.didPop(
      MaterialPageRoute(
          settings: const RouteSettings(name: '/noTitle'),
          builder: (_) => const Placeholder()),
      MaterialPageRoute(
          settings: const RouteSettings(name: '/withTitle'),
          builder: (_) => const Placeholder()),
    );
    await tester.pump();
    expect(captured, 'Route Title');
  });

  testWidgets('didPop ignores when previousRoute is null', (tester) async {
    final observer = TitleObserver(appTitle: (_, __) => '');
    observer.didPop(
      MaterialPageRoute(
          settings: const RouteSettings(name: '/noTitle'),
          builder: (_) => const Placeholder()),
      null,
    );
    await tester.pump();
  });

  testWidgets('falls back to app title when title builder throws', (tester) async {
    bool called = false;
    final observer = TitleObserver(appTitle: (app, route) {
      called = true;
      return '';
    });
    observer.didPush(
      MaterialPageRoute(
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
