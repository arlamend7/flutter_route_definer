/// Configuration options for customizing MaterialPageRoute behavior.
///
/// These options control how the route behaves in the navigation stack,
/// such as whether it maintains state, appears as a fullscreen dialog,
/// allows snapshotting, or can be dismissed by tapping outside.
class RouteOptions {
  /// Whether the route should remain in memory when inactive.
  final bool? maintainState;

  /// Whether the route is a fullscreen modal dialog.
  final bool? fullscreenDialog;

  /// Whether the route content can be snapshot by the OS (e.g., for previews).
  final bool? allowSnapshotting;

  /// Whether the route can be dismissed by tapping outside its bounds.
  final bool? barrierDismissible;

  /// Whether the route should request focus when pushed.
  final bool? requestFocus;

  /// Creates a [RouteOptions] object to configure route behavior.
  ///
  /// All fields are optional and have default values.
  const RouteOptions({
    this.maintainState,
    this.fullscreenDialog,
    this.allowSnapshotting,
    this.barrierDismissible,
    this.requestFocus,
  });

  /// Returns a new [RouteOptions] instance by merging this with [other].
  ///
  /// For each field, if [other] provides a non-null value, it overrides
  /// this instance's corresponding value; otherwise, this instance's value
  /// is retained.
  RouteOptions merge(RouteOptions? other) {
    if (other == null) return this;

    return RouteOptions(
      fullscreenDialog: other.fullscreenDialog ?? fullscreenDialog,
      maintainState: other.maintainState ?? maintainState,
      allowSnapshotting: other.allowSnapshotting ?? allowSnapshotting,
      barrierDismissible: other.barrierDismissible ?? barrierDismissible,
      requestFocus: other.requestFocus ?? requestFocus,
    );
  }
}
