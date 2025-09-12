import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/current_route.dart';

/// Guard used to track whether [check] was invoked.
class TrackingGuard implements RouteGuard {
  /// Indicates if [check] was called.
  bool called = false;

  @override
  Future<void> check(CurrentRoute currentRoute) async {
    called = true;
  }
}

/// Guard that always redirects to `/login`.
class RedirectGuard implements RouteGuard {
  @override
  Future<void> check(CurrentRoute currentRoute) async {
    Navigator.of(currentRoute.context).pushReplacementNamed('/login');
  }
}

/// NavigatorObserver that records pushed route names.
class RecordingObserver extends NavigatorObserver {
  /// Sequence of route names pushed.
  final List<String?> pushes = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes.add(route.settings.name);
  }
}

/// Tests for guard-related behavior in [AppRouter].
void main() {
  testWidgets('AppRouter invokes guards before building page', (WidgetTester tester) async {
    final TrackingGuard guard = TrackingGuard();
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'Test App',
        onUnknownRoute: (RouteSettings settings, RouteState state) =>
            MaterialPageRoute(builder: (_) => const Placeholder(), settings: settings),
      ),
      <RouteDefiner>[
        RouteDefiner(path: '/', builder: (_, __) => const Placeholder()),
        RouteDefiner(path: '/guarded', builder: (_, __) => const Placeholder(), guards: <RouteGuard>[guard]),
      ],
    );

    await tester.pumpWidget(const MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      initialRoute: '/guarded',
    ));
    await tester.pumpAndSettle();
    expect(guard.called, isTrue);
  });

  testWidgets('redirect guard replaces route without double navigation', (WidgetTester tester) async {
    bool built = false;
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'Test App',
        onUnknownRoute: (RouteSettings settings, RouteState state) =>
            MaterialPageRoute(builder: (_) => const Placeholder(), settings: settings),
      ),
      <RouteDefiner>[
        RouteDefiner(path: '/login', builder: (_, __) => const Text('Login')),
        RouteDefiner(
          path: '/protected',
          builder: (_, __) {
            built = true;
            return const Text('Protected');
          },
          guards: <RouteGuard>[RedirectGuard()],
        ),
      ],
    );

    final RecordingObserver observer = RecordingObserver();
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      navigatorObservers: <NavigatorObserver>[observer],
      initialRoute: '/protected',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Protected'), findsNothing);
    expect(built, isFalse);
    expect(observer.pushes, <String?>['/protected', '/login']);
  });
}
