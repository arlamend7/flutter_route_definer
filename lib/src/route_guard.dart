import 'package:route_definer/src/route_state.dart';

abstract class RouteGuard {
  /// Returns a redirect path if blocked, or null if allowed
  String? redirect(RouteState state);
}
