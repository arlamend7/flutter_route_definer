import 'package:route_definer/src/current_route.dart';

/// Interface for defining route guards that control access or
/// redirect based on the current route state.
abstract class RouteGuard {
  /// Creates a [RouteGuard].
  const RouteGuard();

  /// Determines if navigation to a route should be redirected.
  ///
  /// Returns a redirect path as a [String] if access is blocked,
  /// or `null` if navigation is allowed.
  ///
  /// The [state] parameter provides the current [RouteState] with
  /// path, parameters, query, fragment, and arguments.
  Future<void> check(CurrentRoute currentRoute);
}
