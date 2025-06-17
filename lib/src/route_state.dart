class RouteState {
  final String path;
  Map<String, String>? uriParams;
  final Map<String, String> queryParams;
  final String fragment;
  final dynamic arguments;

  RouteState({
    required this.path,
    this.uriParams,
    required this.queryParams,
    required this.fragment,
    required this.arguments,
  });
}
