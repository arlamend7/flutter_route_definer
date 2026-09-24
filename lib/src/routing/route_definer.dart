import 'dart:async';

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/material.dart';
import 'package:route_definer/src/guards/route_guard.dart';
import 'package:route_definer/src/routing/route_options.dart';
import 'package:route_definer/src/routing/route_pattern.dart';
import 'package:route_definer/src/routing/route_state.dart';

/// Creates the native route for a typed page. Preserve the supplied settings.
typedef DefinedRouteFactory = Route<T> Function<T>(
    RouteSettings settings, WidgetBuilder builder, RouteOptions options);

/// Immutable route definition. T is the value returned when its route is popped.
class RouteDefiner<T> {
  RouteDefiner({
    required this.path,
    required this.builder,
    List<RouteGuard> guards = const [],
    Map<String, Object>? data,
    this.title,
    this.options,
    this.routeFactory,
  })  : guards = List.unmodifiable(guards),
        data = data == null ? null : Map.unmodifiable(data),
        pattern = RoutePattern(path);

  final String path;
  final Widget Function(BuildContext, RouteState) builder;

  /// Run in order before the page is built. Return allow, deny or redirect.
  final List<RouteGuard> guards;
  final Map<String, Object>? data;

  /// Resolves this page's complete browser title from its URI state.
  ///
  /// A missing, empty or failed title uses the router's appTitle fallback.
  final FutureOr<String> Function(RouteState)? title;
  final RouteOptions? options;

  /// Overrides the router factory for this page.
  final DefinedRouteFactory? routeFactory;

  /// Validated pattern compiled once per definition.
  final RoutePattern pattern;

  /// Builds a location with encoded path, query and fragment values.
  Uri location({
    Map<String, String> parameters = const {},
    Map<String, dynamic>? queryParameters,
    String? fragment,
  }) =>
      pattern.location(
        parameters: parameters,
        queryParameters: queryParameters,
        fragment: fragment,
      );

  /// Internal typed-page integration used by RouteDefinerRouter.
  @internal
  Page<T> createPage({
    required LocalKey key,
    required RouteSettings settings,
    required WidgetBuilder content,
    required RouteOptions options,
    required void Function(bool, T?) onPopInvoked,
    String? restorationId,
    DefinedRouteFactory? defaultRouteFactory,
  }) =>
      _DefinedPage<T>(
        definition: this,
        content: content,
        options: options,
        defaultRouteFactory: defaultRouteFactory,
        key: key,
        name: settings.name,
        arguments: settings.arguments,
        restorationId: restorationId,
        onPopInvoked: onPopInvoked,
      );
}

class _DefinedPage<T> extends Page<T> {
  const _DefinedPage({
    required this.definition,
    required this.content,
    required this.options,
    required this.defaultRouteFactory,
    required super.key,
    required super.name,
    required super.arguments,
    required super.onPopInvoked,
    super.restorationId,
  });
  final RouteDefiner<T> definition;
  final WidgetBuilder content;
  final RouteOptions options;
  final DefinedRouteFactory? defaultRouteFactory;

  @override
  Route<T> createRoute(BuildContext context) {
    Widget buildContent(BuildContext context) {
      // Reused routes receive new Page settings, not a new immutable builder.
      final page = ModalRoute.of(context)!.settings as _DefinedPage<T>;
      return page.content(context);
    }

    final factory = definition.routeFactory ?? defaultRouteFactory;
    return factory?.call<T>(this, buildContent, options) ??
        MaterialPageRoute<T>(
          settings: this,
          builder: buildContent,
          maintainState: options.maintainState ?? true,
          fullscreenDialog: options.fullscreenDialog ?? false,
          allowSnapshotting: options.allowSnapshotting ?? true,
          barrierDismissible: options.barrierDismissible ?? false,
          requestFocus: options.requestFocus,
        );
  }
}
