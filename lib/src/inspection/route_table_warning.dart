import 'package:route_definer/src/routing/route_definer.dart';

/// A definition that can never win declaration-order matching.
/// Only complete coverage by one earlier pattern is reported; partial overlaps
/// are intentional and are not warnings.
class RouteTableWarning {
  const RouteTableWarning({required this.route, required this.shadowedBy});

  /// The unreachable definition.
  final RouteDefiner<dynamic> route;

  /// An earlier definition matching every location of [route].
  final RouteDefiner<dynamic> shadowedBy;

  @override
  String toString() => 'Route ${route.path} is shadowed by ${shadowedBy.path}. '
      'Place the more specific definition first.';
}
