import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';

RouteDefinerRouter testRouter(List<RouteDefiner<dynamic>> routes) =>
    RouteDefinerRouter(
      routes: routes,
      loadingBuilder: (_) => const Text('Checking access'),
      deniedBuilder: (_, __) => const Text('Access denied'),
      notFoundBuilder: (_, __) => const Text('Not found'),
      errorBuilder: (_, __, retry) => TextButton(
        onPressed: retry,
        child: const Text('Retry'),
      ),
    );
