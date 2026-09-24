import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:route_definer/src/guards/current_route.dart';
import 'package:route_definer/src/routing/route_definer_router.dart';
import 'package:route_definer/src/guards/route_decision.dart';
import 'package:route_definer/src/routing/route_definer.dart';
import 'package:route_definer/src/routing/route_state.dart';

/// Internal lifetime owner for one route's asynchronous checks.
class RouteGate extends StatefulWidget {
  const RouteGate({
    super.key,
    required this.definition,
    required this.routeState,
    required this.router,
    required this.onRedirect,
    this.failure,
    this.onGuardResult,
    this.onFailure,
  });
  final RouteDefiner<dynamic> definition;
  final RouteState routeState;
  final RouteDefinerRouter router;
  final void Function(RedirectNavigation) onRedirect;
  final RouteFailure? failure;
  final void Function(int, RouteDecision)? onGuardResult;
  final void Function(RouteFailure, int?)? onFailure;

  @override
  State<RouteGate> createState() => _RouteGateState();
}

class _RouteGateState extends State<RouteGate> {
  RouteCancellation? _cancellation;
  RouteDecision? _decision;
  RouteFailure? _failure;
  ModalRoute<dynamic>? _owner;
  bool _running = false;
  bool _reported = false;
  int? _guardIndex;

  bool get _active => mounted && (_owner?.isCurrent ?? true);

  CurrentRoute _current(RouteCancellation cancellation) => CurrentRoute(
        context: context,
        route: widget.definition,
        state: widget.routeState,
        cancellation: cancellation,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _owner = ModalRoute.of(context);
    if (!_active && _running) {
      _cancellation?.cancel();
      _running = false;
    } else if (_active && !_running && _decision == null && _failure == null) {
      _start();
    }
  }

  @override
  void didUpdateWidget(RouteGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition ||
        oldWidget.routeState.uri != widget.routeState.uri ||
        oldWidget.routeState.arguments != widget.routeState.arguments) {
      _reset();
    }
  }

  void _reset() {
    _cancellation?.cancel();
    _decision = null;
    _failure = null;
    _reported = false;
    _guardIndex = null;
    _running = false;
    if (_active) _start();
  }

  void _start() {
    if (widget.failure != null) {
      _failure = widget.failure;
      scheduleMicrotask(_report);
      return;
    }
    if (widget.definition.guards.isEmpty) {
      _decision = const RouteDecision.allow();
      return;
    }
    final cancellation = RouteCancellation();
    _cancellation = cancellation;
    _running = true;
    // Application guards may navigate; never invoke them during build.
    scheduleMicrotask(() => _resolve(cancellation));
  }

  bool _valid(RouteCancellation cancellation) =>
      _active &&
      identical(cancellation, _cancellation) &&
      !cancellation.isCancelled;

  Future<RouteDecision> _checkGuards(RouteCancellation cancellation) async {
    final current = _current(cancellation);
    for (var index = 0; index < widget.definition.guards.length; index++) {
      if (!_valid(cancellation)) throw const RouteCancelled();
      _guardIndex = index;
      final decision = await widget.definition.guards[index](current);
      if (!_valid(cancellation)) throw const RouteCancelled();
      widget.onGuardResult?.call(index, decision);
      if (decision is! AllowNavigation) return decision;
    }
    return const RouteDecision.allow();
  }

  Future<void> _resolve(RouteCancellation cancellation) async {
    if (!_valid(cancellation)) return;
    try {
      var future = _checkGuards(cancellation);
      final timeout = widget.router.resolutionTimeout;
      if (timeout != null) future = future.timeout(timeout);
      final result = await Future.any([
        future,
        cancellation.whenCancelled
            .then<RouteDecision>((_) => throw const RouteCancelled()),
      ]);
      if (!_valid(cancellation)) return;
      if (result is RedirectNavigation) {
        _redirect(result, cancellation);
        return;
      }
      setState(() {
        _decision = result;
        _running = false;
      });
    } on RouteCancelled {
      // A removed/replaced/covered route must not consume late completions.
    } catch (error, stackTrace) {
      if (!_valid(cancellation)) return;
      cancellation.cancel();
      setState(() {
        _running = false;
        _failure = RouteFailure(
            error: error, stackTrace: stackTrace, state: widget.routeState);
      });
      _report();
    }
  }

  void _redirect(RedirectNavigation redirect, RouteCancellation cancellation) {
    cancellation.cancel();
    _running = false;
    try {
      widget.onRedirect(redirect);
    } catch (error, stackTrace) {
      if (!_active) return;
      setState(() {
        _failure = RouteFailure(
            error: error, stackTrace: stackTrace, state: widget.routeState);
      });
      _report();
    }
  }

  void _report() {
    if (!mounted || _reported || _failure == null) return;
    _reported = true;
    widget.onFailure?.call(_failure!, _guardIndex);
    try {
      widget.router.onError?.call(_failure!);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'route_definer',
          context: ErrorDescription('while reporting a routing failure')));
    }
  }

  void _retry() {
    if (_active) setState(_reset);
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failure case final failure?) {
      return widget.router.errorBuilder(context, failure, _retry);
    }
    if (_decision is AllowNavigation) {
      return widget.definition.builder(context, widget.routeState);
    }
    final current = _current(_cancellation ?? RouteCancellation());
    if (_decision is DenyNavigation) {
      return widget.router.deniedBuilder(context, current);
    }
    return widget.router.loadingBuilder(current);
  }
}
