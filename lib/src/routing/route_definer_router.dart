import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:route_definer/src/guards/current_route.dart';
import 'package:route_definer/src/inspection/navigation_diagnostics.dart';
import 'package:route_definer/src/inspection/navigation_event.dart';
import 'package:route_definer/src/inspection/route_snapshot.dart';
import 'package:route_definer/src/routing/route_options.dart';
import 'package:route_definer/src/guards/route_decision.dart';
import 'package:route_definer/src/routing/route_definer.dart';
import 'package:route_definer/src/guards/route_gate.dart';
import 'package:route_definer/src/routing/route_pattern.dart';
import 'package:route_definer/src/routing/route_registry.dart';
import 'package:route_definer/src/routing/route_stack.dart';
import 'package:route_definer/src/routing/route_state.dart';
import 'package:route_definer/src/titles/title_observer.dart';

class _RedirectTrace {
  const _RedirectTrace(this.router, this.locations);
  final RouteDefinerRouter router;
  final List<String> locations;

  _RedirectTrace follow(String location) {
    if (locations.contains(location)) {
      throw const RouteRedirectException('A redirect loop was detected.');
    }
    if (locations.length > router.redirectLimit) {
      throw const RouteRedirectException('The redirect limit was exceeded.');
    }
    return _RedirectTrace(router, [...locations, location]);
  }
}

class _Entry {
  _Entry(this.location, this.trace, {this.failure});
  RouteLocation location;
  final _RedirectTrace trace;
  final Object? failure;
  final Completer<Object?> result = Completer<Object?>();

  void complete([Object? value]) {
    if (!result.isCompleted) result.complete(value);
  }
}

class _RemovalObserver extends NavigatorObserver {
  _RemovalObserver(this.onRemove);

  final void Function(Page<dynamic>) onRemove;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Some Flutter versions do not call onDidRemovePage for removeRoute.
    final settings = route.settings;
    if (settings is Page<dynamic>) onRemove(settings);
  }
}

/// One instance-owned route table and Navigator stack.
///
/// Keep an instance outside build and pass config to MaterialApp.router.
/// Use separate instances for nested stacks and dispose them with their owners.
class RouteDefinerRouter extends RouterDelegate<RouteStack>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteStack> {
  RouteDefinerRouter({
    this.initialRoute = '/',
    this.appTitle = '',
    required this.loadingBuilder,
    required this.deniedBuilder,
    required this.notFoundBuilder,
    required this.errorBuilder,
    this.onError,
    this.resolutionTimeout,
    this.redirectLimit = 5,
    this.defaultRouteOptions = const RouteOptions(),
    this.routeFactory,
    required Iterable<RouteDefiner<dynamic>> routes,
    GlobalKey<NavigatorState>? navigatorKey,
    List<NavigatorObserver> observers = const [],
    this.restorationScopeId,
    this.argumentsCodec = const JsonRouteArgumentsCodec(),
    Listenable? refreshListenable,
    this.backButtonDispatcher,
    this.historyLimit = 0,
    this.diagnostics,
  })  : _registry = RouteRegistry(routes),
        navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
        _observers = List.unmodifiable(observers),
        _refreshListenable = refreshListenable {
    if (redirectLimit < 1) {
      throw ArgumentError.value(redirectLimit, 'redirectLimit');
    }
    if (historyLimit < 0) {
      throw ArgumentError.value(historyLimit, 'historyLimit');
    }
    parseRouteUri(initialRoute);
    _refreshListenable?.addListener(refresh);
    _entries = _canonicalStack(parseRouteUri(initialRoute));
    _record(NavigationAction.initialize, source: null, subject: _entries.last);
  }

  final String initialRoute;

  /// Browser title used when the active route has no title of its own.
  final String appTitle;

  /// Required UI while guards are pending. Choose your own or an optional page.
  final Widget Function(CurrentRoute) loadingBuilder;

  /// Required UI when a guard denies access to the destination.
  final Widget Function(BuildContext, CurrentRoute) deniedBuilder;

  /// Required UI when no route definition matches the complete location.
  final Widget Function(BuildContext, RouteState) notFoundBuilder;

  /// Required UI for failed navigation, with a callback to retry its guards.
  final Widget Function(BuildContext, RouteFailure, VoidCallback) errorBuilder;
  final void Function(RouteFailure)? onError;

  /// Optional total guard timeout. Null imposes no timeout.
  final Duration? resolutionTimeout;
  final int redirectLimit;
  final RouteOptions defaultRouteOptions;

  /// Applies to every page, including unknown/error pages, unless overridden.
  final DefinedRouteFactory? routeFactory;
  RouteRegistry _registry;
  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final List<NavigatorObserver> _observers;
  final Listenable? _refreshListenable;
  final RouteArgumentsCodec argumentsCodec;
  final String? restorationScopeId;

  /// Supply a ChildBackButtonDispatcher for a nested Router.
  final BackButtonDispatcher? backButtonDispatcher;

  /// Maximum retained events, oldest to newest. Zero disables retention.
  final int historyLimit;

  /// Null disables logging. Independent of history retention and event listeners.
  final NavigationDiagnostics? diagnostics;

  ListQueue<NavigationEvent>? _history;
  StreamController<NavigationEvent>? _events;
  int _sequence = 0;

  List<_Entry> _entries = [];
  int _nextId = 0;
  int _refresh = 0;
  bool _disposed = false;
  BuildContext? _context;
  PlatformRouteInformationProvider? _provider;
  RouterConfig<RouteStack>? _config;
  TitleObserver? _titleObserver;
  late final NavigatorObserver _removalObserver =
      _RemovalObserver(_didRemovePage);

  List<RouteDefiner<dynamic>> get routes => _registry.routes;

  /// The top managed page of this instance, even while guarded or dialog-covered.
  /// Independent child routers and pageless routes are not included.
  RouteSnapshot get currentRoute => _snapshot(_entries.last);

  /// Resolved, read-only managed pages, bottom (root) to top (current).
  List<RouteSnapshot> get stack => List.unmodifiable(_entries.map(_snapshot));

  /// Retained activity, oldest to newest. Popped/replaced pages may appear here.
  List<NavigationEvent> get history => List.unmodifiable(_history ?? const []);

  /// Asynchronous broadcast events; no replay or retention is implied.
  /// Closes on disposal. Use addListener for existing Router state notifications.
  Stream<NavigationEvent> get events {
    _checkAlive();
    return (_events ??= StreamController<NavigationEvent>.broadcast()).stream;
  }

  bool get _observing =>
      historyLimit > 0 ||
      diagnostics != null ||
      (_events?.hasListener ?? false);

  RouteSnapshot _snapshot(_Entry entry) {
    final location = entry.location;
    final resolved =
        match(location.uri.toString(), arguments: location.arguments);
    return RouteSnapshot(
        id: location.id!,
        state: resolved.state,
        definition: resolved.definition);
  }

  void _record(
    NavigationAction action, {
    required RouteSnapshot? source,
    _Entry? subject,
    int? guardIndex,
    RouteDecision? decision,
    RouteFailure? failure,
  }) {
    // Avoid timestamps, matching, copying and formatting when nobody observes.
    if (_disposed || !_observing) return;
    final resultingStack = stack;
    final route = subject == null ? null : _snapshot(subject);
    final event = NavigationEvent(
      sequence: ++_sequence,
      timestamp: DateTime.now().toUtc(),
      action: action,
      source: source,
      destination: resultingStack.last,
      route: route,
      stack: resultingStack,
      guardIndex: guardIndex,
      guardOutcome: switch (decision) {
        AllowNavigation() => NavigationGuardOutcome.allow,
        DenyNavigation() => NavigationGuardOutcome.deny,
        RedirectNavigation() => NavigationGuardOutcome.redirect,
        null => null,
      },
      redirectLocation:
          decision is RedirectNavigation ? decision.location : null,
      failure: failure == null
          ? null
          : RouteFailure(
              error: failure.error,
              stackTrace: failure.stackTrace,
              state: route?.state ?? resultingStack.last.state),
    );
    if (historyLimit > 0) {
      final history = _history ??= ListQueue<NavigationEvent>();
      history.addLast(event);
      if (history.length > historyLimit) history.removeFirst();
    }
    _events?.add(event);
    diagnostics?.log(event);
  }

  /// Lazily creates the platform URL/history integration.
  RouterConfig<RouteStack> get config {
    _checkAlive();
    WidgetsFlutterBinding.ensureInitialized();
    return _config ??= RouterConfig<RouteStack>(
      routerDelegate: this,
      routeInformationParser:
          RouteDefinerParser(argumentsCodec: argumentsCodec),
      routeInformationProvider: _provider = PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(
          uri: Uri.parse(PlatformDispatcher.instance.defaultRouteName == '/'
              ? initialRoute
              : PlatformDispatcher.instance.defaultRouteName),
        ),
      ),
      backButtonDispatcher: backButtonDispatcher ?? RootBackButtonDispatcher(),
    );
  }

  /// Configures a nested Router that does not report to the platform URL.
  RouterConfig<RouteStack> get nestedConfig => RouterConfig<RouteStack>(
        routerDelegate: this,
        backButtonDispatcher: backButtonDispatcher,
      );

  @override
  RouteStack get currentConfiguration =>
      RouteStack(_entries.map((entry) => entry.location));

  /// Replaces the registry atomically and rechecks the current stack.
  void updateRoutes(Iterable<RouteDefiner<dynamic>> routes) {
    _checkAlive();
    _registry = RouteRegistry(routes);
    refresh();
  }

  /// Invalidates route checks, for example after authentication changes.
  void refresh() {
    _checkAlive();
    _refresh++;
    if (_observing) {
      _record(NavigationAction.refresh,
          source: currentRoute, subject: _entries.last);
    }
    _titleObserver?.refresh(force: true);
    notifyListeners();
  }

  /// Resolves a location to its definition and immutable URI state.
  ({RouteDefiner<dynamic>? definition, RouteState state}) match(String location,
          {Object? arguments}) =>
      _registry.match(parseRouteUri(location), arguments: arguments);

  late final RouteDefiner<dynamic> _fallbackDefinition = RouteDefiner<dynamic>(
    path: '/',
    builder: notFoundBuilder,
  );

  Widget _gate(
          RouteDefiner<dynamic> definition, RouteState state, _Entry entry) =>
      RouteGate(
        key: ValueKey((entry.location.id, _refresh)),
        definition: definition,
        routeState: state,
        router: this,
        failure: entry.failure == null
            ? null
            : RouteFailure(
                error: entry.failure!,
                stackTrace: StackTrace.current,
                state: state),
        onGuardResult: (index, decision) {
          if (_observing && _entries.contains(entry)) {
            _record(NavigationAction.guardResult,
                source: currentRoute,
                subject: entry,
                guardIndex: index,
                decision: decision);
          }
        },
        onFailure: (failure, index) {
          if (_observing && _entries.contains(entry)) {
            _record(NavigationAction.failure,
                source: currentRoute,
                subject: entry,
                guardIndex: index,
                failure: failure);
          }
        },
        onRedirect: (redirect) {
          if (!_entries.contains(entry)) return;
          argumentsCodec.encode(redirect.arguments);
          _change(NavigationAction.redirect, () {
            final index = _entries.indexOf(entry);
            _entries[index] = _entry(redirect.location,
                arguments: redirect.arguments, previousTrace: entry.trace);
            entry.complete();
          }, replace: true, subject: entry);
        },
      );

  _Entry _entry(String location,
      {Object? arguments, String? id, _RedirectTrace? previousTrace}) {
    Uri uri;
    Object? invalidLocation;
    try {
      uri = parseRouteUri(location);
    } catch (error) {
      // Preserve a representable URL while rendering a controlled error page.
      uri = Uri(path: '/');
      invalidLocation = error;
    }
    _nextId++;
    final identity = id ?? 'route-$_nextId';
    // Avoid collisions with restored IDs in later pushes.
    final restoredNumber = int.tryParse(identity.replaceFirst('route-', ''));
    if (restoredNumber != null && restoredNumber > _nextId) {
      _nextId = restoredNumber;
    }
    final routeLocation =
        RouteLocation(uri, arguments: arguments, id: identity);
    try {
      return _Entry(
        routeLocation,
        previousTrace?.follow(uri.toString()) ??
            _RedirectTrace(this, [uri.toString()]),
        failure: invalidLocation,
      );
    } catch (error) {
      return _Entry(routeLocation, previousTrace!, failure: error);
    }
  }

  List<_Entry> _canonicalStack(Uri uri, {Object? arguments}) => [
        for (final location in _registry.initialStack(uri))
          _entry(location.toString(),
              arguments: location == uri ? arguments : null),
      ];

  void _checkAlive() {
    if (_disposed) throw StateError('This router has been disposed.');
  }

  void _change(NavigationAction action, VoidCallback change,
      {bool replace = false, _Entry? subject}) {
    _checkAlive();
    final source = _observing ? currentRoute : null;
    void update() {
      change();
      _record(action, source: source, subject: subject ?? _entries.last);
      notifyListeners();
    }

    final context = _context;
    if (context != null && context.mounted && _config != null) {
      if (replace) {
        Router.neglect(context, update);
      } else {
        Router.navigate(context, update);
      }
    } else {
      update();
    }
  }

  /// Rebuilds the canonical ancestor stack and adds a browser-history entry.
  void go(String location, {Object? arguments}) {
    argumentsCodec.encode(arguments);
    final entries =
        _canonicalStack(parseRouteUri(location), arguments: arguments);
    _change(NavigationAction.reset, () => _replaceStack(entries));
  }

  /// Pushes a URL-addressable page. T must match the definition's result type.
  Future<T?> push<T>(String location, {Object? arguments}) {
    argumentsCodec.encode(arguments);
    parseRouteUri(location);
    final entry = _entry(location, arguments: arguments);
    _change(NavigationAction.push, () => _entries.add(entry));
    return entry.result.future.then((value) => value as T?);
  }

  /// Replaces the top page and current browser-history entry.
  void replace(String location, {Object? arguments}) {
    argumentsCodec.encode(arguments);
    parseRouteUri(location);
    final entry = _entry(location, arguments: arguments);
    _change(NavigationAction.replace, () {
      _entries.removeLast().complete();
      _entries.add(entry);
    }, replace: true);
  }

  /// Asks Navigator to pop, respecting PopScope and pageless dialogs.
  Future<bool> pop<T extends Object?>([T? result]) async {
    final navigator = navigatorKey.currentState;
    return navigator == null ? false : await navigator.maybePop<T>(result);
  }

  /// Removes a managed page by snapshot ID, completing its push with null.
  ///
  /// Updates the declarative stack and replaces the browser history entry.
  /// Returns false for an unknown ID or the sole remaining page. This is not a
  /// pop attempt and does not consult PopScope. Throws after disposal.
  bool remove(String id) {
    _checkAlive();
    final matches = _entries.where((entry) => entry.location.id == id);
    if (matches.isEmpty || _entries.length == 1) return false;
    _removeEntry(matches.first, NavigationAction.remove);
    return true;
  }

  void _replaceStack(List<_Entry> entries) {
    for (final old in _entries) {
      if (!entries.contains(old)) old.complete();
    }
    _entries = entries;
  }

  void _removeEntry(_Entry entry, NavigationAction action, [Object? result]) {
    if (_disposed || !_entries.contains(entry) || _entries.length == 1) return;
    _change(action, () {
      _entries.remove(entry);
      entry.complete(result);
    }, replace: true, subject: entry);
  }

  void _didRemovePage(Page<dynamic> page) {
    final removed =
        _entries.where((entry) => ValueKey(entry.location.id) == page.key);
    if (removed.isEmpty) return;
    _removeEntry(removed.first, NavigationAction.remove);
  }

  @override
  Future<void> setNewRoutePath(RouteStack configuration) {
    _checkAlive();
    final source = _observing ? currentRoute : null;
    final incoming = configuration.locations;
    if (incoming.length == 1 && incoming.single.id == null) {
      try {
        final uri = parseRouteUri(incoming.single.uri.toString());
        _replaceStack(
            _canonicalStack(uri, arguments: incoming.single.arguments));
      } catch (_) {
        _replaceStack([
          _entry(incoming.single.uri.toString(),
              arguments: incoming.single.arguments)
        ]);
      }
    } else {
      final entries = <_Entry>[];
      for (final location in incoming) {
        final existing = _entries.where((entry) =>
            entry.location.id == location.id &&
            entry.location.uri == location.uri);
        if (existing.isNotEmpty) {
          final entry = existing.first;
          // Preserve the pending result and page identity, but honor updated
          // restored arguments so argument-dependent checks run again.
          entry.location = location;
          entries.add(entry);
        } else {
          entries.add(_entry(location.uri.toString(),
              arguments: location.arguments, id: location.id));
        }
      }
      _replaceStack(entries);
    }
    _record(NavigationAction.restore, source: source, subject: _entries.last);
    notifyListeners();
    return SynchronousFuture(null);
  }

  Page<dynamic> _page(_Entry entry) {
    final settings = RouteSettings(
        name: entry.location.uri.toString(),
        arguments: entry.location.arguments);
    final key = ValueKey(entry.location.id);
    final resolved = match(settings.name!, arguments: settings.arguments);
    final definition = entry.failure == null
        ? resolved.definition ?? _fallbackDefinition
        : _fallbackDefinition;
    return definition.createPage(
      key: key,
      restorationId: entry.location.id,
      settings: settings,
      content: (_) => _gate(definition, resolved.state, entry),
      options: defaultRouteOptions.merge(definition.options),
      defaultRouteFactory: routeFactory,
      onPopInvoked: (didPop, result) {
        if (didPop) {
          entry.complete(result);
          _removeEntry(entry, NavigationAction.pop, result);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return Navigator(
      key: navigatorKey,
      restorationScopeId: restorationScopeId,
      pages: [for (final entry in _entries) _page(entry)],
      onDidRemovePage: _didRemovePage,
      observers: [
        _removalObserver,
        _titleObserver ??= TitleObserver(router: this),
        ..._observers,
      ],
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _refreshListenable?.removeListener(refresh);
    _provider?.dispose();
    _titleObserver?.dispose();
    _history?.clear();
    final events = _events;
    if (events != null) unawaited(events.close());
    for (final entry in _entries) {
      entry.complete();
    }
    super.dispose();
  }
}
