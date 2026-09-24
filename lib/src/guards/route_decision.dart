import 'dart:async';

import 'package:route_definer/src/routing/route_state.dart';

/// The terminal result of a navigation check.
sealed class RouteDecision {
  const RouteDecision();
  const factory RouteDecision.allow() = AllowNavigation;
  const factory RouteDecision.deny() = DenyNavigation;
  const factory RouteDecision.redirect(String location, {Object? arguments}) =
      RedirectNavigation;
}

/// Continue to the next check, or build the destination after the last check.
final class AllowNavigation extends RouteDecision {
  const AllowNavigation();
}

/// Show the denied view without building the destination.
final class DenyNavigation extends RouteDecision {
  const DenyNavigation();
}

/// Replace the attempted destination without running its remaining guards.
final class RedirectNavigation extends RouteDecision {
  const RedirectNavigation(this.location, {this.arguments});
  final String location;
  final Object? arguments;
}

/// A failed attempt; the library never automatically logs its arguments.
class RouteFailure {
  const RouteFailure({
    required this.error,
    required this.stackTrace,
    required this.state,
  });
  final Object error;
  final StackTrace stackTrace;
  final RouteState state;
}

/// A cancelled navigation attempt.
class RouteCancelled implements Exception {
  const RouteCancelled();
  @override
  String toString() => 'The navigation attempt is no longer active.';
}

/// Cooperative cancellation for work started by a guard.
///
/// Invalidating a route does not cancel external HTTP requests automatically.
class RouteCancellation {
  final Completer<void> _completion = Completer<void>();
  bool get isCancelled => _completion.isCompleted;
  Future<void> get whenCancelled => _completion.future;

  void cancel() {
    if (!isCancelled) _completion.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const RouteCancelled();
  }
}

/// A redirect chain exceeded its limit or revisited a destination.
class RouteRedirectException implements Exception {
  const RouteRedirectException(this.message);
  final String message;
  @override
  String toString() => message;
}
