import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:route_definer/src/titles/browser_title_stub.dart'
    if (dart.library.js_interop) 'package:route_definer/src/titles/browser_title.dart';
import 'package:route_definer/src/routing/route_definer_router.dart';

/// Updates the browser title for the active named page.
///
/// Dialogs keep the underlying page title. Stale successes and failures are
/// ignored. This does not update AppBar widgets or native window titles.
class TitleObserver extends NavigatorObserver {
  TitleObserver({required RouteDefinerRouter router, this.onTitleChanged})
      : _router = router;

  final RouteDefinerRouter _router;
  final void Function(String)? onTitleChanged;
  final List<Route<dynamic>> _stack = [];
  Route<dynamic>? _active;
  int _generation = 0;
  bool _disposed = false;
  bool _wasAttached = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    refresh();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    if (_stack.isEmpty && previousRoute != null) _stack.add(previousRoute);
    refresh();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    if (_stack.isEmpty && previousRoute != null) _stack.add(previousRoute);
    refresh();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _stack.removeAt(index);
      } else {
        _stack[index] = newRoute;
      }
    } else if (_stack.isEmpty && newRoute != null) {
      _stack.add(newRoute);
    }
    refresh();
  }

  /// Re-evaluates the active page, for example after its title data changes.
  void refresh({bool force = false}) {
    if (_disposed) return;
    _wasAttached = _wasAttached || navigator != null;
    final pages = _stack.reversed
        .where((route) => route is PageRoute && route.settings.name != null);
    final next = pages.isEmpty ? null : pages.first;
    if (!force && identical(next, _active)) return;
    _active = next;
    final generation = ++_generation;
    if (next != null) unawaited(_update(next.settings, generation));
  }

  /// Invalidates pending titles and reads restored settings after Navigator
  /// has applied the new pages, including arguments on a reused route.
  void refreshAfterBuild() {
    if (_disposed) return;
    _generation++;
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh(force: true));
  }

  bool _isCurrent(int generation) =>
      !_disposed &&
      generation == _generation &&
      (!_wasAttached || navigator != null);

  void _publish(String title, int generation) {
    if (!_isCurrent(generation)) return;
    updateBrowserTitle(title);
    onTitleChanged?.call(title);
  }

  Future<void> _update(RouteSettings settings, int generation) async {
    try {
      final match = _router.match(settings.name ?? _router.initialRoute,
          arguments: settings.arguments);
      final title = await match.definition?.title?.call(match.state);
      if (!_isCurrent(generation)) return;
      _publish(title == null || title.isEmpty ? _router.appTitle : title,
          generation);
    } catch (_) {
      _publish(_router.appTitle, generation);
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _stack.clear();
  }
}
