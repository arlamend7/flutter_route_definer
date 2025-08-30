import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/current_route.dart';

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

  /// Optional authorization check that returns `true` when the user is
  /// allowed to access this route.
  final Future<bool> Function(CurrentRoute currentRoute)? isAuthorized;

  /// List of route guards to control access or redirection for this route.
  ///
  /// Guards are checked in order and can trigger redirects by returning
  /// a non-null route path.
  final List<RouteGuard> guards;

  /// Arbitrary data associated with the route which can be consumed by
  /// widgets or middleware.
  final Map<String, Object>? data;

  /// Lazily evaluated title used by [TitleObserver] when updating the
  /// browser or app bar title.
  final Future<String> Function()? title;

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
    this.isAuthorized,
    this.data,
    this.title,
    this.guards = const [],
    this.options,
  });
}
