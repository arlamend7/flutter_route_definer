import 'package:flutter/material.dart';
import 'package:route_definer/default_pages.dart' as default_router;
import 'package:route_definer/route_definer.dart';

void main() => runApp(MaterialApp.router(routerConfig: router.config));

final RouteDefinerRouter router = RouteDefinerRouter(
  loadingBuilder: (_) => const default_router.LoadingPage(),
  deniedBuilder: (_, __) => const default_router.DeniedPage(),
  notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
  errorBuilder: (_, __, retry) => default_router.ErrorPage(onRetry: retry),
  routes: [
    RouteDefiner<void>(
      path: '/',
      builder: (_, __) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => router.push<void>('/about'),
            child: const Text('Open About'),
          ),
        ),
      ),
    ),
    RouteDefiner<void>(
      path: '/about',
      builder: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('About')),
        body: const Center(child: Text('Hello!')),
      ),
    ),
  ],
);
