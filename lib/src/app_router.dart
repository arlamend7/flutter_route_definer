// lib/route_definer.dart

import 'package:route_definer/src/global_route_definer.dart';
import 'package:route_definer/src/route_definer.dart';
import 'package:route_definer/src/route_state.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static late GlobalRouteDefiner _globalDefiner;
  static late List<RouteDefiner> _routes;

  static String get initialRoute => _globalDefiner.initialRoute;
  static String get title => _globalDefiner.title;

  static set routes(List<RouteDefiner> routeList) => _routes = routeList;

  static void init(GlobalRouteDefiner definer, List<RouteDefiner> routeList) {
    _globalDefiner = definer;
    _routes = routeList;
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final result = analyzeRoute(settings);
    final state = result.state;
    final match = result.match;
    final isNear = result.isNear;

    if (match == null) {
      if (isNear) return null;
      return _globalDefiner.onUnknownRoute(settings, state);
    }

    final redirect = match.evaluateRedirect(state);
    if (redirect != null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          var redirection = Navigator.popAndPushNamed(context, redirect);
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

  static Route<dynamic>? onUnknownRoute(RouteSettings settings) {
    final state = buildRouteState(settings);
    return _globalDefiner.onUnknownRoute(settings, state);
  }

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

  static (RouteDefiner?, bool) matchRoute(String path) {
    for (var route in _routes) {
      final params = extractPathParams(route.path, path);
      if (params != null) return (route, false);
      if (isNearMatch(route.path, path)) return (null, true);
    }
    return (null, false);
  }

  static Map<String, String>? extractPathParams(String pattern, String actual) {
    final regExpPattern = pattern.replaceAllMapped(RegExp(r':(\w+)'), (match) => '(?<${match[1]}>[\\w-]+)');
    final regExp = RegExp('^$regExpPattern\$');
    final match = regExp.firstMatch(actual);
    if (match == null) return null;
    return {for (var name in match.groupNames) name: match.namedGroup(name)!};
  }

  static bool isNearMatch(String routePattern, String path) {
    if (!routePattern.contains('/:')) return false;
    return routePattern.startsWith(path);
  }

  static ({RouteState state, RouteDefiner? match, bool isNear}) analyzeRoute(RouteSettings settings) {
    final state = buildRouteState(settings);
    final (match, isNear) = matchRoute(state.path);
    if (match != null) {
      state.uriParams = extractPathParams(match.path, state.path);
    }
    return (state: state, match: match, isNear: isNear);
  }
}
