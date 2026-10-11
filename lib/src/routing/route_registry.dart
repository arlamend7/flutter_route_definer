import 'package:route_definer/src/inspection/route_table_warning.dart';
import 'package:route_definer/src/routing/route_definer.dart';
import 'package:route_definer/src/routing/route_state.dart';

/// Immutable registration and first-complete-match lookup.
class RouteRegistry {
  RouteRegistry(Iterable<RouteDefiner<dynamic>> definitions)
      : routes = List.unmodifiable(definitions) {
    final signatures = <String>{};
    for (final route in routes) {
      if (!signatures.add(route.pattern.signature)) {
        final path = route.path;
        throw ArgumentError('Duplicate or ambiguous route: $path');
      }
    }
  }
  final List<RouteDefiner<dynamic>> routes;

  late final List<RouteTableWarning> warnings = List.unmodifiable([
    for (var index = 1; index < routes.length; index++)
      for (var earlier = 0; earlier < index; earlier++)
        if (routes[earlier].pattern.covers(routes[index].pattern))
          RouteTableWarning(route: routes[index], shadowedBy: routes[earlier]),
  ]);

  ({RouteDefiner<dynamic>? definition, RouteState state}) match(Uri uri,
      {Object? arguments}) {
    final segments = uri.pathSegments;
    for (final definition in routes) {
      final parameters = definition.pattern.matchSegments(segments);
      if (parameters != null) {
        return (
          definition: definition,
          state: RouteState(uri, uriParams: parameters, arguments: arguments),
        );
      }
    }
    return (definition: null, state: RouteState(uri, arguments: arguments));
  }

  /// Registered ancestors, followed by the final destination even if unknown.
  List<Uri> initialStack(Uri uri) {
    final result = <Uri>[];
    final segments = uri.pathSegments;
    for (var length = 0; length < segments.length; length++) {
      final prefix = length == 0
          ? Uri(path: '/')
          : Uri(pathSegments: ['', ...segments.take(length)]);
      if (match(prefix).definition != null) result.add(prefix);
    }
    if (result.isEmpty || result.last != uri) result.add(uri);
    return result;
  }
}
