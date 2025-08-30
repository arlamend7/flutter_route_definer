import 'package:flutter/material.dart';
import 'package:route_definer/src/current_route.dart';

/// Widget that handles route guards and optional authentication before
/// displaying the final page to the user.
class RouteLoaderWidget extends StatefulWidget {
  /// Information about the route being navigated to.
  final CurrentRoute currentRoute;

  /// Optional widget displayed while guards or authentication are resolving.
  final Widget? loader;

  /// Stream completing when all route guards have finished execution.
  final Stream<void> guardStream;

  /// Optional asynchronous task used to validate authorization.
  final Future<Widget?>? authenticationTask;

  /// Creates a [RouteLoaderWidget] that resolves guards and authentication.
  const RouteLoaderWidget({
    super.key,
    required this.currentRoute,
    required this.guardStream,
    required this.authenticationTask,
    required this.loader,
  });

  @override
  State<RouteLoaderWidget> createState() => _RouteLoaderWidgetState();
}

/// State for [RouteLoaderWidget] that manages guard and authentication logic.
class _RouteLoaderWidgetState extends State<RouteLoaderWidget> {
  /// The widget currently being displayed, if any.
  Widget? _pageToShow;

  @override
  void initState() {
    super.initState();
    _handleRoutingLogic();
  }

  /// Runs both authentication and guard checks before loading the final page.
  Future<void> _handleRoutingLogic() async {
    final authWidget = await _runAuthentication();
    if (!mounted) return;

    if (authWidget != null) {
      _setPage(authWidget);
      return;
    }

    await _checkRouteGuards();
    if (!mounted) return;

    _loadFinalPage();
  }

  /// Runs the optional authentication task and returns a widget if needed.
  Future<Widget?> _runAuthentication() async {
    if (widget.authenticationTask == null) return null;
    return await widget.authenticationTask;
  }

  /// Waits for all guards to complete.
  Future<void> _checkRouteGuards() async {
    await widget.guardStream.drain<void>();
  }

  /// Loads the actual page for the current route.
  void _loadFinalPage() {
    final page =
        widget.currentRoute.route.builder(context, widget.currentRoute.state);
    _setPage(page);
  }

  /// Updates the state with [widgetToShow] as the current page.
  void _setPage(Widget widgetToShow) {
    setState(() {
      _pageToShow = widgetToShow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _pageToShow ??
        widget.loader ??
        const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
