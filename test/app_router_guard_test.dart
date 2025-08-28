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
}
