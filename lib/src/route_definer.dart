import 'package:route_definer/route_definer.dart';
import 'package:flutter/material.dart';

/// Defines a single route in the app with its path, widget builder,
/// authorization requirement, and optional guards.
class RouteDefiner {
  /// The path pattern of the route, e.g., '/user/:id'.
  final String path;

  /// The widget builder function that builds the page for this route.
  ///
  /// It receives the current [BuildContext] and the [RouteState] with
  /// parsed parameters, query, fragment, and arguments.
  final Widget Function(BuildContext context, RouteState state) builder;

  /// Whether this route requires user authorization.
  ///
  /// If true, the app router will check authorization before allowing access.
  /// Defaults to false.
  final bool requireAuthorization;

  /// List of route guards to control access or redirection for this route.
  ///
  /// Guards are checked in order and can trigger redirects by returning
  /// a non-null route path.
  final List<RouteGuard> guards;

  /// Optional route-specific overrides for MaterialPageRoute behavior.
  final RouteOptions? options;

  /// Creates a new [RouteDefiner].
  ///
  /// [path] and [builder] are required.
  /// [requireAuthorization] defaults to false.
  /// [guards] defaults to an empty list.
  RouteDefiner({
    required this.path,
    required this.builder,
    this.requireAuthorization = false,
    this.guards = const [],
    this.options,
  });

  /// Evaluates the guards to determine if a redirect should happen.
  ///
  /// Iterates over all [guards], calling their [RouteGuard.redirect] method
  /// with the current [RouteState].
  ///
  /// Returns the redirect path string if any guard requests a redirect,
  /// or null if no redirect is needed.
  String? evaluateRedirect(RouteState state) {
    for (final guard in guards) {
      final result = guard.redirect(state);
      if (result != null) return result;
    }
    return null;
  }
}
