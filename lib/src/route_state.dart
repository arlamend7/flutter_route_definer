/// Represents the current state of a route during navigation,
/// including path, parameters, query strings, fragment, and arguments.
class RouteState {
  /// The path portion of the route (e.g. "/user/123").
  final String path;

  /// The URI parameters extracted from the path (e.g. `id` in "/user/:id").
  /// This can be null if there are no parameters.
  Map<String, String>? uriParams;

  /// The query parameters from the URL (e.g. `?sort=asc&filter=active`).
  final Map<String, String> queryParams;

  /// The fragment part of the URL (e.g. `#section2`).
  final String fragment;

  /// Optional arguments passed along with the route.
  final Object? arguments;

  /// Creates a [RouteState] object with all the relevant route information.
  ///
  /// [path] must not be null.
  /// [uriParams] can be null if there are no dynamic segments.
  /// [queryParams], [fragment], and [arguments] are required.
  RouteState({
    required this.path,
    this.uriParams,
    required this.queryParams,
    required this.fragment,
    required this.arguments,
  });
}
