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

  /// All decoded values in URI order. Missing keys return an empty list.
  /// The returned list is immutable.
  List<String> queryValues(String name) => queryParamsAll[name] ?? const [];

  String? _singleQuery(String name) {
    final values = queryValues(name);
    if (values.isEmpty) return null;
    if (values.length != 1) {
      throw FormatException('Expected one query value: $name');
    }
    return values.single;
  }

  /// A signed decimal integer; null when missing. Empty, malformed and repeated
  /// values throw FormatException. Hexadecimal and whitespace are not accepted.
  int? queryInt(String name) {
    final value = _singleQuery(name);
    if (value == null) return null;
    final parsed = RegExp(r'^[+-]?[0-9]+$').stringMatch(value) == value
        ? int.tryParse(value, radix: 10)
        : null;
    if (parsed == null) {
      throw FormatException('Expected an integer query: $name');
    }
    return parsed;
  }

  /// Exactly `true` or `false`; null when missing. All other values, including
  /// empty and repeated values, throw FormatException.
  bool? queryBool(String name) {
    final value = _singleQuery(name);
    if (value == null) return null;
    if (value == 'true') return true;
    if (value == 'false') return false;
    throw FormatException('Expected a boolean query: $name');
  }

  T argumentsAs<T>() {
    final value = arguments;
    if (value is! T) throw FormatException('Expected arguments of type $T');
    return value;
  }
}
