import 'package:flutter/material.dart';
import 'package:route_definer/material.dart';

void main() => runApp(MaterialApp.router(routerConfig: router.config));

final router = createMaterialRouter(
  routes: [
    RouteDefiner<void>.simple(
      path: '/',
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () =>
                RouteDefinerRouter.of(context).push<void>('/about'),
            child: const Text('Open About'),
          ),
        ),
      ),
    ),
    RouteDefiner<void>.simple(
      path: '/about',
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('About')),
        body: const Center(child: Text('Hello!')),
      ),
    ),
  ],
);
