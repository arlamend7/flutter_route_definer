import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';

class CurrentRoute {
  final BuildContext context;
  final RouteDefiner route;
  final RouteState state;

  CurrentRoute({
    required this.context,
    required this.route,
    required this.state,
  });
}
