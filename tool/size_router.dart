// Two-screen Router size fixture with explicitly selected optional pages.
import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/default_pages.dart' as default_router;

void main() {
  late final RouteDefinerRouter router;
  router = RouteDefinerRouter(
    loadingBuilder: (_) => const default_router.LoadingPage(),
    deniedBuilder: (_, __) => const default_router.DeniedPage(),
    notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
    errorBuilder: (_, failure, retry) =>
        default_router.ErrorPage(onRetry: retry),
    routes: [
      for (final path in ['/', '/detail'])
        RouteDefiner<void>(
            path: path,
            builder: (context, _) => Scaffold(
                    body: TextButton(
                  onPressed: () => router.push<void>('/detail'),
                  child: Text(path == '/detail' ? 'Detail' : 'Home'),
                )))
    ],
  );
  runApp(MaterialApp.router(routerConfig: router.config));
}
