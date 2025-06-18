// lib/route_definer.dart

import 'package:route_definer/src/global_route_definer.dart';
import 'package:route_definer/src/route_definer.dart';
import 'package:route_definer/src/route_state.dart';
import 'package:flutter/material.dart';

/// A central router class that manages app navigation, route matching,
/// authorization checks, redirects, and unknown route handling.
///
/// Use [init] to set up global route definitions and routes.
///
/// The class provides methods to generate routes dynamically based on
/// [RouteSettings], including authorization and redirection logic.
class AppRouter {
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
      if (isNear) return null; // Possibly fallback handling outside
      return _globalDefiner.onUnknownRoute(settings, state);
    }

    final redirect = match.evaluateRedirect(state);
    if (redirect != null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          final redirection = Navigator.popAndPushNamed(context, redirect);
          if (_globalDefiner.onRedirect != null) {
            return FutureBuilder(
              future: redirection,
              builder: (_, __) => const Center(child: CircularProgressIndicator()),
            );
          }
          return _globalDefiner.onRedirect!.call(state, redirect, redirection);
        },
      );
    }

    final isAuth = !match.requireAuthorization || (_globalDefiner.isAuthorized?.call(state) ?? false);
    if (!isAuth && _globalDefiner.unauthorizedBuilder != null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => _globalDefiner.unauthorizedBuilder!(context, state),
      );
    }

    return MaterialPageRoute(settings: settings, builder: (ctx) => match.builder(ctx, state));
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
