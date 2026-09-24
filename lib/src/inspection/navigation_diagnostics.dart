import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:meta/meta.dart' show internal;
import 'package:route_definer/src/inspection/navigation_event.dart';
import 'package:route_definer/src/inspection/route_snapshot.dart';

/// Opt-in router diagnostics. No logger runs unless configured on the router.
///
/// Defaults log registered patterns instead of concrete URIs. Enable each
/// sensitive field explicitly. The logger receives only the formatted string.
class NavigationDiagnostics {
  const NavigationDiagnostics({
    this.logger,
    this.includeParameters = false,
    this.includeArguments = false,
    this.includeData = false,
    this.includeErrorDetails = false,
  });

  /// Defaults to Flutter's debugPrint. Exceptions from the logger are ignored.
  final void Function(String)? logger;
  final bool includeParameters;
  final bool includeArguments;
  final bool includeData;
  final bool includeErrorDetails;

  /// Produces a single JSON line with consistently redacted route information.
  String format(NavigationEvent event) => jsonEncode({
        'sequence': event.sequence,
        'action': event.action.name,
        'from': _route(event.source),
        'to': _route(event.destination),
        if (event.route != null) 'route': _route(event.route),
        'stack': event.stack.map(_route).toList(),
        if (event.guardIndex != null) 'guardIndex': event.guardIndex,
        if (event.guardOutcome != null) 'guard': event.guardOutcome!.name,
        if (event.redirectLocation != null)
          'redirect': includeParameters ? event.redirectLocation : '[redacted]',
        if (event.failure case final failure?) ...{
          'errorType': failure.error.runtimeType.toString(),
          if (includeErrorDetails) ...{
            'error': _describe(failure.error),
            'stackTrace': _describe(failure.stackTrace),
          },
        },
      });

  Map<String, Object?>? _route(RouteSnapshot? route) => route == null
      ? null
      : {
          'id': route.id,
          'pattern': route.definition?.path ?? '<unmatched>',
          if (includeParameters) ...{
            'uri': route.state.uri.toString(),
            'pathParameters': route.state.uriParams,
            'queryParameters': route.state.queryParamsAll,
            'fragment': route.state.fragment,
          },
          if (includeArguments) 'arguments': _describe(route.state.arguments),
          if (includeData) 'data': _describe(route.data),
        };

  String _describe(Object? value) {
    try {
      return value.toString();
    } catch (_) {
      return '<unprintable>';
    }
  }

  @internal
  void log(NavigationEvent event) {
    try {
      final message = format(event);
      if (logger case final callback?) {
        callback(message);
      } else {
        debugPrint(message);
      }
    } catch (_) {
      // Diagnostic code must never change the outcome of navigation/guards.
    }
  }
}
