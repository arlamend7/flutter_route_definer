// Browser-only validation entry point used by tool/browser_check.mjs.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/default_pages.dart' as default_router;
import 'package:web/web.dart' as web;

void main() {
  final errors = <String>[];
  final built = <String>[];
  final logs = <String>[];
  var selected = -1;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  late final RouteDefinerRouter router;
  RouteDefiner<T> page<T>(String path, String title) => RouteDefiner<T>(
        path: path,
        title: (state) {
          final arguments = state.arguments;
          if (arguments is Map && arguments['title'] is String) {
            return arguments['title'] as String;
          }
          return '$title ${state.uri}';
        },
        builder: (_, state) {
          built.add(state.uri.toString());
          return Scaffold(body: Text(state.uri.toString()));
        },
      );
  router = RouteDefinerRouter(
    historyLimit: 32,
    diagnostics: NavigationDiagnostics(logger: logs.add),
    loadingBuilder: (_) => const default_router.LoadingPage(),
    deniedBuilder: (_, __) => const default_router.DeniedPage(),
    errorBuilder: (_, failure, retry) =>
        default_router.ErrorPage(onRetry: retry),
    appTitle: 'Browser test',
    onError: (failure) => errors.add(failure.error.toString()),
    notFoundBuilder: (_, __) => const Scaffold(body: Text('Unknown')),
    routes: [
      page<void>('/', 'Home'),
      page<int>('/item/:id', 'Item'),
      page<void>('/other', 'Other'),
      RouteDefiner<void>(
          path: '/redirect',
          guards: [
            (_) => const RouteDecision.redirect('/other'),
          ],
          builder: (_, __) => throw StateError('Redirected page was built')),
    ],
  );
  globalContext.setProperty(
      'routeDefinerCheck'.toJS,
      ((JSString request) {
        final command = jsonDecode(request.toDart) as Map<String, dynamic>;
        switch (command['action']) {
          case 'push':
            unawaited(router.push<int>(command['uri'] as String, arguments: {
              'source': 'browser'
            }).then((value) => selected = value ?? -1));
          case 'go':
            router.go(command['uri'] as String);
          case 'replace':
            router.replace(command['uri'] as String);
          case 'pop':
            unawaited(router.pop<int>(42));
          case 'restoreArguments':
            final locations = router.currentConfiguration.locations;
            unawaited(router.setNewRoutePath(RouteStack([
              ...locations.take(locations.length - 1),
              RouteLocation(locations.last.uri,
                  id: locations.last.id,
                  arguments: {'title': 'Restored title'}),
            ])));
          case 'remove':
            router.remove(router.currentRoute.id);
        }
        final current = router.currentRoute;
        return jsonEncode({
          'uri': router.currentConfiguration.uri.toString(),
          'stack': router.currentConfiguration.locations
              .map((e) => e.uri.toString())
              .toList(),
          'ids':
              router.currentConfiguration.locations.map((e) => e.id).toList(),
          'arguments': router.currentConfiguration.locations.last.arguments,
          'current': {
            'path': current.state.path,
            'pattern': current.definition?.path,
            'parameters': current.state.uriParams,
            'fragment': current.state.fragment,
          },
          'inspectionStack':
              router.stack.map((e) => e.state.uri.toString()).toList(),
          'history': router.history
              .map((e) => {
                    'action': e.action.name,
                    'from': e.source?.state.uri.toString(),
                    'to': e.destination?.state.uri.toString(),
                    'stack':
                        e.stack.map((r) => r.state.uri.toString()).toList(),
                  })
              .toList(),
          'logs': logs,
          'title': web.document.title,
          'errors': errors,
          'built': built,
          'selected': selected,
          'wasm': const bool.fromEnvironment('dart.tool.dart2wasm'),
        }).toJS;
      }).toJS);
  runApp(MaterialApp.router(
      routerConfig: router.config, restorationScopeId: 'browser'));
}
