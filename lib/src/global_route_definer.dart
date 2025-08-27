import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/current_route.dart';

/// Defines global route-related settings and behaviors for the app router.
///
/// This includes the initial route, app title, authorization logic,
/// redirect handling, unauthorized access widget builder, and
/// unknown route handling.
class GlobalRouteDefiner {
  /// The initial route path to use when the app starts or when
  /// no specific route is given.
  final String initialRoute;

  /// The title of the application.
  final String title;

  /// A widget builder invoked when a redirect occurs.
  ///
  /// Receives the current [RouteState], the redirect target path,
  /// and the future representing the navigation action.
  final Widget Function(CurrentRoute currentRoute)? loaderBuilder;

  /// A widget builder for unauthorized access cases.
  ///
  /// Called when a route requires authorization but the user
  /// is not authorized. Provides the current [BuildContext]
  /// and [RouteState].
  final Widget Function(BuildContext, CurrentRoute)? unauthorizedBuilder;

  /// A function that returns a [MaterialPageRoute] for unknown routes.
  ///
  /// Called when a route cannot be matched by the router.
  final MaterialPageRoute Function(RouteSettings, RouteState) onUnknownRoute;

  /// Global route behavior options applied to all routes unless overridden.
  final RouteOptions defaultRouteOptions;

  /// Creates a new [GlobalRouteDefiner] instance.
  ///
  /// [initialRoute] and [title] are required.
  /// [onUnknownRoute] must be provided to handle unknown routes.
  ///
  /// The other parameters are optional and provide
  /// customization for authorization, redirects, and unauthorized views.
  const GlobalRouteDefiner({
    required this.initialRoute,
    required this.title,
    this.loaderBuilder,
    this.unauthorizedBuilder,
    required this.onUnknownRoute,
    this.defaultRouteOptions = const RouteOptions(),
  });
}
