/// Immutable URI information for one navigation attempt.
class RouteState {
  RouteState(
    this.uri, {
    Map<String, String>? uriParams,
    this.arguments,
  })  : uriParams = uriParams == null ? null : Map.unmodifiable(uriParams),
        queryParams = Map.unmodifiable(uri.queryParameters),
        queryParamsAll = Map.unmodifiable({
          for (final entry in uri.queryParametersAll.entries)
            entry.key: List<String>.unmodifiable(entry.value),
        });

  /// Full URI, including authority when supplied by an external link.
  final Uri uri;
  String get path => uri.path;
  String get fragment => uri.fragment;

  /// Decoded parameters, or null when no definition matched.
  final Map<String, String>? uriParams;

  /// Single-value query view; use queryParamsAll for repeated keys.
  final Map<String, String> queryParams;
  final Map<String, List<String>> queryParamsAll;

  /// Application-owned payload. Its contents are not deep-copied.
  final Object? arguments;

  String requirePathParameter(String name) {
    final value = uriParams?[name];
    if (value == null) throw FormatException('Missing path parameter: $name');
    return value;
  }

  int pathInt(String name) {
    final value = int.tryParse(requirePathParameter(name));
    if (value == null) throw FormatException('Expected an integer: $name');
    return value;
  }

  T argumentsAs<T>() {
    final value = arguments;
    if (value is! T) throw FormatException('Expected arguments of type $T');
    return value;
  }
}
