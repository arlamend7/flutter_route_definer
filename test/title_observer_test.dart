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
}
