import 'package:flutter/widgets.dart';
import 'package:route_definer/src/guards/route_decision.dart';
import 'package:route_definer/src/routing/route_definer.dart';
import 'package:route_definer/src/routing/route_state.dart';

/// Information and cooperative cancellation for one navigation attempt.
class CurrentRoute {
  CurrentRoute({
    required this.context,
    required this.route,
    required this.state,
    RouteCancellation? cancellation,
  }) : cancellation = cancellation ?? RouteCancellation();

  final BuildContext context;
  final RouteDefiner<dynamic> route;
  final RouteState state;
  final RouteCancellation cancellation;

  bool get isActive => context.mounted && !cancellation.isCancelled;
}
