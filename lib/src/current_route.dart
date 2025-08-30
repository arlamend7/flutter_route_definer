import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';

/// Contextual information about a navigation action, passed to guards and
/// loaders to make decisions about the current route.
class CurrentRoute {
  /// Build context associated with the navigation.
  final BuildContext context;

  /// The matched [RouteDefiner] for the navigation request.
  final RouteDefiner route;

  /// The parsed [RouteState] containing path and parameter information.
  final RouteState state;

  /// Creates a [CurrentRoute] with the given [context], [route], and [state].
  CurrentRoute({
    required this.context,
    required this.route,
    required this.state,
  });
}
