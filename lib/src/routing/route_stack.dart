import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:route_definer/src/routing/route_pattern.dart';

/// Converts application arguments to/from JSON-compatible history state.
///
/// Keep sensitive data out of URLs and browser history. Use opaque identifiers
/// and retrieve protected data after authorization instead.
abstract class RouteArgumentsCodec {
  const RouteArgumentsCodec();
  Object? encode(Object? arguments);
  Object? decode(Object? encoded);
}

/// The default supports JSON values and rejects unsupported payloads eagerly.
class JsonRouteArgumentsCodec extends RouteArgumentsCodec {
  const JsonRouteArgumentsCodec();
  @override
  Object? encode(Object? arguments) {
    try {
      return jsonDecode(jsonEncode(arguments));
    } on Object {
      throw ArgumentError(
          'Router arguments must be JSON values or use a RouteArgumentsCodec.');
    }
  }

  @override
  Object? decode(Object? encoded) => encoded;
}

/// A restorable location in a Router-managed stack.
class RouteLocation {
  const RouteLocation(this.uri, {this.arguments, this.id});
  final Uri uri;
  final Object? arguments;
  final String? id;
}

/// Canonical state reported to Flutter's Router and browser history.
class RouteStack {
  RouteStack(Iterable<RouteLocation> locations)
      : locations = List.unmodifiable(locations) {
    if (this.locations.isEmpty) {
      throw ArgumentError('A route stack must not be empty');
    }
  }
  final List<RouteLocation> locations;
  Uri get uri => locations.last.uri;
}

/// Parses full URIs and round-trips serialized navigation stacks.
class RouteDefinerParser extends RouteInformationParser<RouteStack> {
  const RouteDefinerParser({
    this.argumentsCodec = const JsonRouteArgumentsCodec(),
  });
  final RouteArgumentsCodec argumentsCodec;

  @override
  Future<RouteStack> parseRouteInformation(RouteInformation routeInformation) {
    final state = routeInformation.state;
    if (state is Map && state['route_definer'] == 3 && state['stack'] is List) {
      try {
        final locations = <RouteLocation>[];
        final ids = <String>{};
        for (final value in state['stack'] as List) {
          if (value is! Map ||
              value['uri'] is! String ||
              value['id'] is! String) {
            throw const FormatException('Invalid route history entry');
          }
          final id = value['id'] as String;
          if (id.isEmpty || !ids.add(id)) {
            throw const FormatException('Empty or duplicate page id');
          }
          locations.add(RouteLocation(
            parseRouteUri(value['uri'] as String),
            arguments: argumentsCodec.decode(value['arguments']),
            id: id,
          ));
        }
        if (locations.isNotEmpty &&
            locations.last.uri == routeInformation.uri) {
          return SynchronousFuture(RouteStack(locations));
        }
      } on Object {
        // External history state is untrusted. Fall back to the visible URI.
      }
    }
    return SynchronousFuture(RouteStack([RouteLocation(routeInformation.uri)]));
  }

  @override
  RouteInformation restoreRouteInformation(RouteStack configuration) =>
      RouteInformation(
        uri: configuration.uri,
        state: {
          'route_definer': 3,
          'stack': [
            for (final location in configuration.locations)
              {
                'uri': location.uri.toString(),
                'id': location.id,
                'arguments': argumentsCodec.encode(location.arguments),
              },
          ],
        },
      );
}
