import 'dart:async';

import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';

/// A [NavigatorObserver] that updates the browser title whenever navigation
/// occurs, using either a custom title generator or a default implementation.
class TitleObserver extends NavigatorObserver {
  /// Default function for combining the app name and route name into a title.
  static String Function(String, String?) defaultTitleGenerator =
      (appName, routeName) =>
          (routeName?.isEmpty ?? true) ? appName : "$appName | $routeName";

  /// Function used to produce the title shown in the browser.
  late String Function(String appName, String? routeName) appTitle;

  /// Creates a [TitleObserver] that uses [appTitle] to generate titles.
  TitleObserver({required this.appTitle});

  /// Called when a route has been pushed onto the navigator.
  @override
  void didPush(Route route, Route? previousRoute) {
    // The observer hooks are synchronous, so we intentionally ignore the
    // returned future. Updates are fire-and-forget.
    unawaited(_updateTitle(route.settings));
  }

  /// Called when a route has been replaced by another.
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) {
      // Replacement happens during navigation; awaiting is unnecessary.
      unawaited(_updateTitle(newRoute.settings));
    }
  }

  /// Called when a route has been popped off the navigator.
  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute != null) {
      // We only care about side effects on the browser title.
      unawaited(_updateTitle(previousRoute.settings));
    }
  }

  /// Updates the browser title based on the provided route [settings].
  ///
  /// This method retrieves the [RouteDefiner] for the settings and applies
  /// its asynchronous title resolver when available. Navigator observer
  /// callbacks have no cancellation mechanism, so no cancellation token is
  /// accepted.
  ///
  /// Returns a [Future] that completes after the title has been updated.
  /// If an error occurs, the application title is used as a fallback.
  Future<void> _updateTitle(RouteSettings settings) async {
    try {
      final definer = AppRouter.analyzeRoute(settings);
      final titleFn = definer.match?.title;
      if (titleFn != null) {
        final title = await titleFn();
        updateBrowserTitle(appTitle(AppRouter.title, title));
      } else {
        updateBrowserTitle(appTitle(AppRouter.title, null));
      }
    } catch (_) {
      updateBrowserTitle(AppRouter.title);
    }
  }
}
