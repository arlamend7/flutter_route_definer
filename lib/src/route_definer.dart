import 'package:route_definer/src/route_guard.dart';
import 'package:route_definer/src/route_state.dart';
import 'package:flutter/material.dart';

class RouteDefiner {
  final String path;
  final Widget Function(BuildContext context, RouteState state) builder;
  final bool requireAuthorization;
  final List<RouteGuard> guards;

  RouteDefiner({required this.path, required this.builder, this.requireAuthorization = false, this.guards = const []});

  String? evaluateRedirect(RouteState state) {
    for (final guard in guards) {
      final result = guard.redirect(state);
      if (result != null) return result;
    }
    return null;
  }
}
