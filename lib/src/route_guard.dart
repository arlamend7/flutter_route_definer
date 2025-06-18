import 'package:flutter_app_router/flutter_app_router.dart';
import 'package:flutter_app_router/src/route_state.dart';

abstract class RouteGuard {
  /// Returns a redirect path if blocked, or null if allowed
  String? redirect(RouteState state);
}
