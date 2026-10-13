import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:route_definer/src/routing/route_definer.dart';
import 'package:route_definer/src/routing/route_options.dart';

/// Native page presets that preserve typed results and Router page settings.
abstract final class RouteFactories {
  /// Material behavior, including Flutter's platform-adaptive transitions.
  static PageRoute<T> material<T>(RouteSettings settings, WidgetBuilder builder,
          RouteOptions options) =>
      MaterialPageRoute<T>(
        settings: settings,
        builder: builder,
        maintainState: options.maintainState ?? true,
        fullscreenDialog: options.fullscreenDialog ?? false,
        allowSnapshotting: options.allowSnapshotting ?? true,
        barrierDismissible: options.barrierDismissible ?? false,
        requestFocus: options.requestFocus,
      );

  /// Cupertino behavior, including supported interactive back gestures.
  static PageRoute<T> cupertino<T>(RouteSettings settings,
          WidgetBuilder builder, RouteOptions options) =>
      CupertinoPageRoute<T>(
        settings: settings,
        builder: builder,
        maintainState: options.maintainState ?? true,
        fullscreenDialog: options.fullscreenDialog ?? false,
        allowSnapshotting: options.allowSnapshotting ?? true,
        barrierDismissible: options.barrierDismissible ?? false,
        requestFocus: options.requestFocus,
      );

  /// A page with zero forward and reverse transition durations.
  static PageRoute<T> noTransition<T>(RouteSettings settings,
          WidgetBuilder builder, RouteOptions options) =>
      transitions(
        transitionsBuilder: (_, __, ___, child) => child,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ).call<T>(settings, builder, options);

  /// Supplies animation only; this factory owns page construction and settings.
  /// Reverse duration defaults to the forward duration. Durations cannot be
  /// negative. Custom animations do not provide Cupertino interactive gestures.
  static DefinedPageRouteFactory transitions({
    required RouteTransitionsBuilder transitionsBuilder,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Duration? reverseTransitionDuration,
  }) {
    final reverse = reverseTransitionDuration ?? transitionDuration;
    if (transitionDuration.isNegative || reverse.isNegative) {
      throw ArgumentError('Transition durations must not be negative.');
    }
    return <T>(settings, builder, options) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, __) => builder(context),
          transitionsBuilder: transitionsBuilder,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: reverse,
          maintainState: options.maintainState ?? true,
          fullscreenDialog: options.fullscreenDialog ?? false,
          allowSnapshotting: options.allowSnapshotting ?? true,
          barrierDismissible: options.barrierDismissible ?? false,
          requestFocus: options.requestFocus,
        );
  }
}
