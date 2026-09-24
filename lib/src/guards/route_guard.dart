import 'dart:async';

import 'package:route_definer/src/guards/current_route.dart';
import 'package:route_definer/src/guards/route_decision.dart';

/// A synchronous or asynchronous check before a route is displayed.
///
/// Return allow to continue, deny to display the denied view, or redirect to
/// replace the destination. Throw an exception to display the error/retry view.
typedef RouteGuard = FutureOr<RouteDecision> Function(CurrentRoute route);
