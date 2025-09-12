import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/current_route.dart';
import 'package:route_definer/widgets/route_loader_widget.dart';

/// Tests for [RouteLoaderWidget] guard and authentication handling.
void main() {
  testWidgets('shows auth widget when authentication provides one',
      (WidgetTester tester) async {
    final RouteDefiner route =
        RouteDefiner(path: '/dummy', builder: (_, __) => const Text('Final'));
    final RouteState state = RouteState(
        path: '/dummy',
        uriParams: null,
        queryParams: const <String, String>{},
        fragment: '',
        arguments: null);

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (BuildContext ctx) {
        final CurrentRoute current =
            CurrentRoute(context: ctx, route: route, state: state);
        return RouteLoaderWidget(
          currentRoute: current,
          loader: const Text('Loading'),
          guardStream: const Stream.empty(),
          authenticationTask: Future<Widget?>.value(const Text('Auth')),
        );
      }),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Auth'), findsOneWidget);
  });

  testWidgets('builds final page after guards complete',
      (WidgetTester tester) async {
    final RouteDefiner route =
        RouteDefiner(path: '/dummy', builder: (_, __) => const Text('Final'));
    final RouteState state = RouteState(
        path: '/dummy',
        uriParams: null,
        queryParams: const <String, String>{},
        fragment: '',
        arguments: null);

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (BuildContext ctx) {
        final CurrentRoute current =
            CurrentRoute(context: ctx, route: route, state: state);
        return RouteLoaderWidget(
          currentRoute: current,
          loader: const Text('Loading'),
          guardStream: Stream<void>.value(null),
          authenticationTask: Future<Widget?>.value(null),
        );
      }),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Final'), findsOneWidget);
  });
}
