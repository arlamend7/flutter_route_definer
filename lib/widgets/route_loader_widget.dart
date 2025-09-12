import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';

/// Widget that handles route guards and optional authentication before
/// displaying the final page to the user.
class RouteLoaderWidget extends StatelessWidget {
  /// Information about the route being navigated to.
  final CurrentRoute currentRoute;

  /// Optional widget displayed while guards or authentication are resolving.
  final Widget? loader;

  /// Stream completing when all route guards have finished execution.
  final Stream<void> guardStream;

  /// Optional asynchronous task used to validate authorization.
  final Future<Widget?>? authenticationTask;

  /// Memoized resolution future so work runs only once.
  final Future<WidgetBuilder> _resolution;

  /// Creates a [RouteLoaderWidget] that resolves guards and authentication.
  RouteLoaderWidget({
    super.key,
    required this.currentRoute,
    required this.guardStream,
    required this.authenticationTask,
    required this.loader,
  }) : _resolution = _resolve(
          currentRoute: currentRoute,
          guardStream: guardStream,
          authenticationTask: authenticationTask,
        );

  /// Runs both authentication and guard checks, producing a [WidgetBuilder]
  /// to render when ready. Never throws in control flow.
  static Future<WidgetBuilder> _resolve({
    required CurrentRoute currentRoute,
    required Stream<void> guardStream,
    required Future<Widget?>? authenticationTask,
  }) async {
    // 1) Authentication (optional). If it yields a widget, show that immediately.
    if (authenticationTask != null) {
      final authWidget = await authenticationTask;
      if (authWidget != null) {
        return (_) => authWidget;
      }
    }

    // 2) Guards — ignore errors (no-throw business flow).
    try {
      await guardStream.handleError((_) {}).drain<void>();
    } catch (_) {
      // Swallow to keep a no-throw surface; proceed to final page.
    }

    // 3) Build the final page lazily with the ambient BuildContext.
    return (context) => currentRoute.route.builder(context, currentRoute.state);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WidgetBuilder>(
      future: _resolution,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          final builder = snap.data!;
          return builder(context);
        }
        // Loading or error → show loader (fallback to a spinner).
        return loader ??
            const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
      },
    );
  }
}
