/// A validated, reusable path pattern with whole-segment :parameters.
///
/// Matching is case-sensitive and preserves trailing slashes. Literal segments
/// are literal text, not regular expressions. URI segments are decoded once,
/// so an encoded slash remains data inside its original segment.
class RoutePattern {
  /// Creates a pattern such as /users/:id.
  RoutePattern(this.path) {
    if (!path.startsWith('/') || path.contains('?') || path.contains('#')) {
      throw ArgumentError.value(path, 'path', 'Expected an absolute path only');
    }
    final uri = parseRouteUri(path);
    if (uri.hasAuthority || uri.hasScheme) {
      throw ArgumentError.value(path, 'path', 'Route patterns must be local');
    }
    _segments = List.unmodifiable(uri.pathSegments);
    final names = <String>{};
    for (final segment in _segments) {
      if (segment.startsWith(':')) {
        final name = segment.substring(1);
        if (!RegExp(r'^[A-Za-z_]\w*$').hasMatch(name) || !names.add(name)) {
          throw ArgumentError.value(
              path, 'path', 'Invalid or duplicate parameter name: $name');
        }
      }
    }
    parameters = Set.unmodifiable(names);
  }

  final String path;
  late final List<String> _segments;
  late final Set<String> parameters;

  /// Detects equivalent, ambiguous patterns at registration.
  String get signature => _segments
      .map((part) => part.startsWith(':') ? ':' : Uri.encodeComponent(part))
      .join('/');

  /// Matches already decoded URI segments without reparsing them.
  Map<String, String>? matchSegments(List<String> segments) {
    if (_segments.length != segments.length) return null;
    final values = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final pattern = _segments[i];
      if (pattern.startsWith(':')) {
        if (segments[i].isEmpty) return null;
        values[pattern.substring(1)] = segments[i];
      } else if (pattern != segments[i]) {
        return null;
      }
    }
    return values;
  }

  Map<String, String>? match(String path) =>
      matchSegments(parseRouteUri(path).pathSegments);

  /// Generates an encoded URI and rejects missing or unused parameters.
  Uri location({
    Map<String, String> parameters = const {},
    Map<String, dynamic>? queryParameters,
    String? fragment,
  }) {
    if (parameters.length != this.parameters.length ||
        !this.parameters.every(parameters.containsKey) ||
        parameters.values.any((value) => value.isEmpty)) {
      final expected = this.parameters;
      throw ArgumentError('Expected nonempty parameters: $expected');
    }
    if (_segments.isEmpty) {
      return Uri(
          path: '/', queryParameters: queryParameters, fragment: fragment);
    }
    return Uri(
      pathSegments: [
        '',
        for (final segment in _segments)
          segment.startsWith(':') ? parameters[segment.substring(1)]! : segment,
      ],
      queryParameters: queryParameters,
      fragment: fragment,
    );
  }
}

/// Parses an absolute route path or external URI, rejecting invalid escapes.
///
/// Applications decide which external domains and schemes to accept.
Uri parseRouteUri(String location) {
  if (RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(location)) {
    throw FormatException('Invalid percent escape in route', location);
  }
  final uri = Uri.parse(location);
  if (uri.path.isNotEmpty && !uri.path.startsWith('/')) {
    throw FormatException('Expected an absolute route path', location);
  }
  uri.pathSegments;
  uri.queryParametersAll;
  return uri.path.isEmpty ? uri.replace(path: '/') : uri;
}
