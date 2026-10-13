/// Opt-in ready-made status views and a Material router setup helper.
library;

import 'package:flutter/material.dart';
import 'package:route_definer/default_pages.dart';
import 'package:route_definer/route_definer.dart';

export 'default_pages.dart';
export 'route_definer.dart';

/// Creates a router with the optional status pages and Material page behavior.
/// Keep the returned router outside build and dispose it with its owner.
/// All explicit constructor options remain available, including view overrides.
RouteDefinerRouter createMaterialRouter({
  required Iterable<RouteDefiner<dynamic>> routes,
  String initialRoute = '/',
  String appTitle = '',
  Widget Function(CurrentRoute)? loadingBuilder,
  Widget Function(BuildContext, CurrentRoute)? deniedBuilder,
  Widget Function(BuildContext, RouteState)? notFoundBuilder,
  Widget Function(BuildContext, RouteFailure, VoidCallback)? errorBuilder,
  void Function(RouteFailure)? onError,
  Duration? resolutionTimeout,
  int redirectLimit = 5,
  RouteOptions defaultRouteOptions = const RouteOptions(),
  DefinedRouteFactory? routeFactory,
  DefinedPageRouteFactory? pageRouteFactory,
  GlobalKey<NavigatorState>? navigatorKey,
  List<NavigatorObserver> observers = const [],
  String? restorationScopeId,
  RouteArgumentsCodec argumentsCodec = const JsonRouteArgumentsCodec(),
  Listenable? refreshListenable,
  BackButtonDispatcher? backButtonDispatcher,
  int historyLimit = 0,
  NavigationDiagnostics? diagnostics,
}) =>
    RouteDefinerRouter(
      routes: routes,
      initialRoute: initialRoute,
      appTitle: appTitle,
      loadingBuilder: loadingBuilder ?? (_) => const LoadingPage(),
      deniedBuilder: deniedBuilder ?? (_, __) => const DeniedPage(),
      notFoundBuilder: notFoundBuilder ?? (_, __) => const NotFoundPage(),
      errorBuilder: errorBuilder ?? (_, __, retry) => ErrorPage(onRetry: retry),
      onError: onError,
      resolutionTimeout: resolutionTimeout,
      redirectLimit: redirectLimit,
      defaultRouteOptions: defaultRouteOptions,
      routeFactory: routeFactory,
      pageRouteFactory: pageRouteFactory,
      navigatorKey: navigatorKey,
      observers: observers,
      restorationScopeId: restorationScopeId,
      argumentsCodec: argumentsCodec,
      refreshListenable: refreshListenable,
      backButtonDispatcher: backButtonDispatcher,
      historyLimit: historyLimit,
      diagnostics: diagnostics,
    );
