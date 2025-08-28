import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/current_route.dart';

class TrackingGuard implements RouteGuard {
  bool called = false;
  @override
  Future<void> check(CurrentRoute currentRoute) async {
    called = true;
  }
}

class RedirectGuard implements RouteGuard {
  @override
  Future<void> check(CurrentRoute currentRoute) async {
    Navigator.of(currentRoute.context).pushReplacementNamed('/login');
  }
}

class RecordingObserver extends NavigatorObserver {
  final List<String?> pushes = [];
  @override
  void didPush(Route route, Route? previousRoute) {
    pushes.add(route.settings.name);
  }
}

void main() {
  testWidgets('AppRouter invokes guards before building page', (tester) async {
    final guard = TrackingGuard();
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'Test App',
        onUnknownRoute: (settings, state) =>
            MaterialPageRoute(builder: (_) => const Placeholder(), settings: settings),
      ),
      [
        RouteDefiner(path: '/', builder: (_, __) => const Placeholder()),
        RouteDefiner(path: '/guarded', builder: (_, __) => const Placeholder(), guards: [guard]),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      initialRoute: '/guarded',
    ));
    await tester.pumpAndSettle();
    expect(guard.called, isTrue);
  });

  testWidgets('redirect guard replaces route without double navigation',
      (tester) async {
    bool built = false;
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'Test App',
        onUnknownRoute: (settings, state) =>
            MaterialPageRoute(builder: (_) => const Placeholder(), settings: settings),
      ),
      [
        RouteDefiner(path: '/login', builder: (_, __) => const Text('Login')),
        RouteDefiner(
          path: '/protected',
          builder: (_, __) {
            built = true;
            return const Text('Protected');
          },
          guards: [RedirectGuard()],
        ),
      ],
    );

    final observer = RecordingObserver();
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      navigatorObservers: [observer],
      initialRoute: '/protected',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Protected'), findsNothing);
    expect(built, isFalse);
    expect(observer.pushes, ['/protected', '/login']);
  });
}
