import 'package:flutter_app_router/src/route_state.dart';
import 'package:flutter/material.dart';

class GlobalRouteDefiner {
  final String initialRoute;
  final String title;
  final bool Function(RouteState)? isAuthorized;
  final Widget Function(RouteState, String, Future<void>)? onRedirect;
  final Widget Function(BuildContext, RouteState)? unauthorizedBuilder;
  final MaterialPageRoute Function(RouteSettings, RouteState) onUnknownRoute;

  const GlobalRouteDefiner({
    required this.initialRoute,
    required this.title,
    this.onRedirect,
    this.isAuthorized,
    this.unauthorizedBuilder,
    required this.onUnknownRoute,
  });
}
