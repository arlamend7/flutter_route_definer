import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:route_definer/default_pages.dart' as default_router;
import 'package:route_definer/route_definer.dart';

void main() => runApp(MaterialApp.router(routerConfig: router.config));

// One router for this small application's lifetime.
final router = RouteDefinerRouter(
  loadingBuilder: (_) => const default_router.LoadingPage(),
  deniedBuilder: (_, __) => const default_router.DeniedPage(),
  notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
  errorBuilder: (_, __, retry) => default_router.ErrorPage(onRetry: retry),
  historyLimit: kDebugMode ? 20 : 0,
  diagnostics: kDebugMode
      ? NavigationDiagnostics(
          logger: (message) => debugPrint('[Router] $message'),
          includeParameters: true,
          includeArguments: true,
          includeData: true,
          includeErrorDetails: true
          // Arguments, custom data and error details stay out of logs.
        )
      : null,
  routes: [
    RouteDefiner<void>(
      path: '/',
      builder: (_, __) => debugPage('Home'),
    ),
    RouteDefiner<void>(
      path: '/items/:id',
      data: const {'section': 'catalog'},
      builder: (_, __) => debugPage('Item'),
    ),
  ],
);

Widget debugPage(String title) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (title == 'Home')
            FilledButton(
              onPressed: () => router.push<void>(
                '/items/42?tab=reviews#details',
                arguments: {'source': 'home'},
              ),
              child: const Text('Open item 42'),
            ),
          if (kDebugMode)
            StreamBuilder<NavigationEvent>(
              stream: router.events,
              builder: (context, _) {
                final current = router.currentRoute;
                final state = current.state;
                return SelectableText([
                  'CURRENT ROUTE',
                  'URI: ${state.uri}',
                  'Path: ${state.path}',
                  'Path parameters: ${state.uriParams}',
                  'Query parameters: ${state.queryParamsAll}',
                  'Fragment: ${state.fragment}',
                  'Arguments: ${state.arguments}',
                  'Definition: ${current.definition?.path}',
                  'Custom data: ${current.data}',
                  '\nSTACK (bottom → top)',
                  ...router.stack.map((route) => '${route.state.uri}'),
                  '\nHISTORY (oldest → newest, up to 20 events)',
                  ...router.history.map((event) =>
                      '${event.action.name}: ${event.source?.state.path} → '
                      '${event.destination?.state.path}'),
                ].join('\n'));
              },
            ),
        ],
      ),
    );
