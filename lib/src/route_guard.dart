import 'package:app_router/app_router.dart';
import 'package:app_router/src/route_state.dart';

abstract class RouteGuard {
  /// Returns a redirect path if blocked, or null if allowed
  String? redirect(RouteState state);
}
