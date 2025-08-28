import 'package:route_definer/src/current_route.dart';

/// Interface for defining route guards that control access or
/// redirect based on the current route state.
abstract class RouteGuard {
  /// Creates a [RouteGuard].
  const RouteGuard();

  /// Performs any logic required before allowing navigation.
  ///
  /// Implementations may trigger navigation actions (e.g., redirects)
  /// by using the provided [CurrentRoute].
  Future<void> check(CurrentRoute currentRoute);
}
