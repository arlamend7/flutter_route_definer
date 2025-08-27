// lib/route_definer.dart

import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/current_route.dart';
import 'package:route_definer/src/deafault_guard_handler_page.dart';

/// A central router class that manages app navigation, route matching,
/// authorization checks, redirects, and unknown route handling.
///
/// Use [init] to set up global route definitions and routes.
///
/// The class provides methods to generate routes dynamically based on
/// [RouteSettings], including authorization and redirection logic.
class AppRouter {
  AppRouter._(); // Prevents instantiation

  static late GlobalRouteDefiner _globalDefiner;
  static late List<RouteDefiner> _routes;

  /// Returns the initial route defined in the global route definer.
  static String get initialRoute => _globalDefiner.initialRoute;

  /// Returns the app's title from the global route definer.
  static String get title => _globalDefiner.title;

  /// Sets the list of route definitions for the app.
  static set routes(List<RouteDefiner> routeList) => _routes = routeList;

  /// Initializes the router with a [GlobalRouteDefiner] and a list of [RouteDefiner] routes.
  ///
  /// This must be called before using any other routing methods.
  static void init(GlobalRouteDefiner definer, List<RouteDefiner> routeList) {
    _globalDefiner = definer;
    _routes = routeList;
  }

  /// Generates a route based on the provided [RouteSettings].
  ///
  /// Handles matching routes, redirects, authorization checks, and fallbacks.
  /// Returns a [Route] if a matching route is found, or null if a near match exists.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final result = analyzeRoute(settings);
    final state = result.state;
    final match = result.match;
    final isNear = result.isNear;

    if (match == null) {
      if (isNear) return null;
      return _globalDefiner.onUnknownRoute(settings, state);
    }

    return _buildMaterialPageRoute(settings, (ctx) {
      final CurrentRoute currentRoute = CurrentRoute(context: ctx, route: match, state: state);

      return RouteLoaderWidget(
        currentRoute: currentRoute,
        loader: _globalDefiner.loaderBuilder?.call(currentRoute),
        guardStream: _resolveRedirection(match, currentRoute),
        authenticationTask: match.isAuthorized
            ?.call(currentRoute)
            .then((value) => value ? null : _globalDefiner.unauthorizedBuilder?.call(ctx, currentRoute)),
      );
    }, match.options);
  }

  static Stream<String?> _resolveRedirection(RouteDefiner route, CurrentRoute currentRoute) async* {
    for (var element in route.guards) {
      await element.check(currentRoute);
      if (!currentRoute.context.mounted) {
        return;
      }
    }
  }

  /// Builds a [MaterialPageRoute] using either the provided route options
  /// or the global default options defined in [GlobalRouteDefiner].
  ///
  /// This method centralizes route creation logic to support consistent customization.
  static MaterialPageRoute _buildMaterialPageRoute(
    RouteSettings settings,
    WidgetBuilder builder,
    RouteOptions? localOptions,
  ) {
    final opts = _globalDefiner.defaultRouteOptions.merge(localOptions);

    return MaterialPageRoute(
      settings: settings,
      builder: builder,
      maintainState: opts.maintainState ?? true,
      fullscreenDialog: opts.fullscreenDialog ?? false,
      allowSnapshotting: opts.allowSnapshotting ?? true,
      barrierDismissible: opts.barrierDismissible ?? false,
      requestFocus: opts.requestFocus,
    );
  }

  /// Handles unknown routes (e.g., 404) based on [RouteSettings].
  ///
  /// Returns a route created by the global definer's unknown route handler.
  static Route<dynamic>? onUnknownRoute(RouteSettings settings) {
    final state = buildRouteState(settings);
    return _globalDefiner.onUnknownRoute(settings, state);
  }

  /// Builds a [RouteState] object from [RouteSettings], parsing path, query parameters, fragment, and arguments.
  static RouteState buildRouteState(RouteSettings settings) {
    final routeName = settings.name?.isNotEmpty == true ? settings.name! : _globalDefiner.initialRoute;
    final uri = Uri.parse(routeName);
    return RouteState(
      path: uri.path,
      queryParams: uri.queryParameters,
      fragment: uri.fragment,
      arguments: settings.arguments,
    );
  }

  /// Matches a given [path] against the list of registered routes.
  ///
  /// Returns a tuple with the matching [RouteDefiner] (or null) and a boolean
  /// indicating if the path is a near match.
  static (RouteDefiner?, bool) matchRoute(String path) {
    for (var route in _routes) {
      final params = extractPathParams(route.path, path);
      if (params != null) return (route, false);
      if (isNearMatch(route.path, path)) return (null, true);
    }
    return (null, false);
  }

  /// Extracts dynamic path parameters from a route [pattern] using the actual [actual] path.
  ///
  /// For example, pattern '/user/:id' and actual '/user/42' returns {'id': '42'}.
  /// Returns null if the actual path does not match the pattern.
  static Map<String, String>? extractPathParams(String pattern, String actual) {
    final regExpPattern = pattern.replaceAllMapped(RegExp(r':(\w+)'), (match) => '(?<${match[1]}>[\\w-]+)');
    final regExp = RegExp('^$regExpPattern\$');
    final match = regExp.firstMatch(actual);
    if (match == null) return null;
    return {for (var name in match.groupNames) name: match.namedGroup(name)!};
  }

  /// Returns true if [path] is a near match to the route pattern [routePattern].
  ///
  /// Used to detect if a route is close to matching, for example when
  /// parameters are missing or incomplete.
  static bool isNearMatch(String routePattern, String path) {
    if (!routePattern.contains('/:')) return false;
    return routePattern.startsWith(path);
  }

  /// Analyzes [RouteSettings] by building the [RouteState] and matching it against routes.
  ///
  /// Returns a tuple containing the route state, the matched route (if any), and whether the match is near.
  static ({RouteState state, RouteDefiner? match, bool isNear}) analyzeRoute(RouteSettings settings) {
    final state = buildRouteState(settings);
    final (match, isNear) = matchRoute(state.path);
    if (match != null) {
      state.uriParams = extractPathParams(match.path, state.path);
    }
    return (state: state, match: match, isNear: isNear);
  }
}
