import 'package:route_definer/src/guards/route_decision.dart';
import 'package:route_definer/src/inspection/route_snapshot.dart';

/// Observed managed-stack mutations or guard activity, not animation completion.
enum NavigationAction {
  initialize,
  push,
  pop,
  replace,
  remove,
  redirect,
  reset,
  restore,
  refresh,
  guardResult,
  failure,
}

enum NavigationGuardOutcome { allow, deny, redirect }

/// One immutable event. History is ordered oldest to newest by [sequence].
///
/// The source/destination are the active managed pages before/after the event.
/// [route] identifies its subject, including a removed page below the top.
/// History and event streams contain unredacted application data. Logging has
/// separate opt-in controls. Opaque payload/error objects remain references.
class NavigationEvent {
  NavigationEvent({
    required this.sequence,
    required this.timestamp,
    required this.action,
    required this.source,
    required this.destination,
    required Iterable<RouteSnapshot> stack,
    this.route,
    this.guardIndex,
    this.guardOutcome,
    this.redirectLocation,
    this.failure,
  }) : stack = List.unmodifiable(stack);

  final int sequence;
  final DateTime timestamp;
  final NavigationAction action;
  final RouteSnapshot? source;
  final RouteSnapshot? destination;
  final RouteSnapshot? route;

  /// Resulting managed stack, bottom to top.
  final List<RouteSnapshot> stack;

  /// Zero-based position in the definition's guards, when applicable.
  final int? guardIndex;
  final NavigationGuardOutcome? guardOutcome;
  final String? redirectLocation;
  final RouteFailure? failure;

  /// Safe summary without URI values, arguments, data or exception messages.
  @override
  String toString() => 'NavigationEvent($sequence, ${action.name})';
}
