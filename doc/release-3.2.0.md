# Release 3.2.0: easier setup and safer page customization

Status: implementation candidate on `release/3.2.0`, not a published release.
This document tracks all twelve requested improvements. Existing 3.1.0 work is
retained and regression-tested; it is not presented as newly introduced in 3.2.0.

## Scope and acceptance criteria

| # | Requested change | Implementation and acceptance coverage |
|---|---|---|
| 1 | Preserve screen state during guard refresh | Existing stable page/gate identity retained. Refresh hides protected content, disables focus/tickers, preserves state on allow, and discards it on deny/error. `test/guards/refresh_state_test.dart` checks edited forms and cancelled attempts. New preset tests repeat refresh with each factory. |
| 2 | Definition-based typed navigation | Existing `pushRoute`, `goRoute`, `replaceRoute` retained. Definition identity, URI construction and shadowing are checked before mutation. `typed_navigation_test.dart` and `tool/check_typed_navigation.py` verify inferred results and compile-time rejection. String navigation remains available for links. |
| 3 | Platform validation | Android/iOS fixture and CI jobs, patched SDK/dependency matrix and shared browser scenarios are retained. Native fixture now uses the Cupertino preset. Browser fixture now uses the optional helper and no-transition preset. See the validation record below; physical gestures, actual Safari, OS cold/warm links and process-death restoration remain release gates until independently verified. |
| 4 | Navigation combinations | Existing deterministic randomized tests retained: seeds 7, 42 and 20260927 mix 100 operations each, checking stack/model agreement, IDs, result completion and stale guards. |
| 5 | Shadowed route diagnostics | Existing opt-in `router.routeWarnings` retained. Matching remains declaration ordered; equivalent patterns still fail registration. Warning tests cover broad parameter patterns hiding specific routes. |
| 6 | Runnable app recipes | Retained tabs, intended destination after login and dirty-form handling remain in `example/lib/recipes.dart`, with widget tests and `doc/recipes.md`. No automatic shell routing is introduced. |
| 7 | Easy-start router factory | New optional `material.dart` import exposes `createMaterialRouter`. Default loading, denied, missing and retry views work without four callbacks. Every explicit constructor option is forwarded; overrides remain possible. Minimal example uses the helper. |
| 8 | Native route presets | New `RouteFactories.material`, `cupertino`, `noTransition`, `transitions`. Tests check exact settings, all five options, typed pop, refresh and restoration. Material retains Flutter's own platform-adaptive transitions. |
| 9 | Safer factory contract | Additive `DefinedPageRouteFactory` returns `PageRoute<T>`. `pageRouteFactory` validates exact settings identity before installing the route. Existing `DefinedRouteFactory` and `routeFactory` remain available. Ambiguous configuration throws. |
| 10 | Definition constructors | `.simple` removes the state parameter while forwarding definition options. `.redirect` runs preceding guards then resolves a destination through the existing pipeline. Tests cover denial, async cancellation and redirect loops. |
| 11 | Context lookup | `RouteDefinerRouter.of` and `maybeOf` resolve the nearest router from managed screens, including nested stacks. Missing scope has a descriptive error/null result. Explicit router references remain supported. |
| 12 | Query and codec helpers | Nullable strict scalar query parsing, immutable repeated values and a callback codec with JSON validation. Tests cover malformed/repeated inputs, custom payload round trips and corrupt restoration fallback. |

## Quick start

The convenience import exports the core API and optional status pages:

```dart
import 'package:flutter/material.dart';
import 'package:route_definer/material.dart';

final about = RouteDefiner<void>.simple(
  path: '/about',
  builder: (_) => const Scaffold(body: Text('About')),
);
final router = createMaterialRouter(routes: [
  RouteDefiner<void>.simple(
    path: '/',
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => RouteDefinerRouter.of(context).pushRoute(about),
        child: const Text('About'),
      ),
    ),
  ),
  about,
]);
```

Pass `router.config` to `MaterialApp.router`. Own/dispose the router outside
`build`. The helper accepts the same configuration options as the explicit
constructor. For example, override `deniedBuilder` or `errorBuilder` to use your
design system. The core import alone does not expose this opt-in helper.

## Page factories

```dart
final picker = RouteDefiner<int>(
  path: '/picker',
  builder: (_, state) => const PickerScreen(), // Your application widget.
  pageRouteFactory: RouteFactories.cupertino,
);
final Future<int?> selection = router.pushRoute(picker);
```

Presets also work with the legacy `routeFactory` parameter. Prefer
`pageRouteFactory` for its stronger type contract and settings validation.
A definition's factory (either kind) overrides the router's factory (either
kind). Setting both factory parameters at the same level throws `ArgumentError`.
If neither is set, the existing Material default remains in effect.

```dart
final fade = RouteFactories.transitions(
  transitionsBuilder: (_, animation, __, child) =>
      FadeTransition(opacity: animation, child: child),
  transitionDuration: const Duration(milliseconds: 200),
  reverseTransitionDuration: const Duration(milliseconds: 120),
);
```

Reverse duration defaults to forward duration; negative durations are rejected.
`noTransition` uses zero durations in both directions. Every preset forwards
maintainState, fullscreenDialog, allowSnapshotting, barrierDismissible and
requestFocus. Per-definition options still merge with router defaults.
Native Flutter semantics apply: custom transitions do not automatically provide
Cupertino interactive swipe behavior. Material already adapts its transitions to
the platform.

For a custom `DefinedPageRouteFactory`, return a `PageRoute<T>` and pass the
**exact supplied settings object** to its constructor. Do not copy the settings
or discard the supplied builder. The settings are the Router's typed `Page<T>`
and carry identity, arguments, restoration and pop callbacks. Reused native
routes receive updated page settings, so the library's content builder resolves
the latest page. The legacy callback is retained without narrowing its return
type; its existing modal/page assumptions still apply.

## Redirect definitions

```dart
final oldProfile = RouteDefiner<void>.redirect(
  path: '/old-profile',
  redirect: (_) => '/profile',
);
```

The callback accepts `RouteState` and returns `String` or `Future<String>`.
Optional preceding guards run first; denial prevents the redirect callback.
Exceptions, timeout, retry, cancellation and redirect limits use the existing
guard pipeline. The redirect callback should compute a destination, not navigate
as a side effect. A cancelled callback may finish but cannot navigate. Arguments
are not implicitly forwarded. Use an ordinary guard returning
`RouteDecision.redirect(..., arguments: ...)` when you need that control.

## Context and query helpers

`of(context)` throws `FlutterError` outside a managed Navigator; `maybeOf(context)`
returns null. Both use the nearest inherited router. Use a context inside the
screen, rather than above `MaterialApp.router`. A normal nested Navigator that
is not a separate RouteDefinerRouter inherits the enclosing router. Independent
nested routers shadow it. Services and cross-stack actions should keep explicit
references. Lookup establishes a scope dependency, not a subscription to every
navigation event; use the existing listenable/event APIs for reactive route data.

| Helper | Missing key | Invalid or repeated scalar | Valid example |
|---|---|---|---|
| `queryInt(name)` | null | `FormatException` | Signed decimal integer; no hex or whitespace |
| `queryBool(name)` | null | `FormatException` | Exactly lowercase `true` or `false` |
| `queryValues(name)` | Empty immutable list | Returns all decoded values in URI order | `?tag=a&tag=b` gives `['a', 'b']` |

Empty scalar values are invalid. Supply application defaults with `??`; malformed
inputs are deliberately not silently replaced. Existing `queryParams` and
`queryParamsAll` remain available.

## Callback codecs

```dart
final codec = RouteArgumentsCodec.callbacks(
  encode: (value) => value == null
      ? null
      : {'date': (value as DateTime).toIso8601String()},
  decode: (value) => value == null
      ? null
      : DateTime.parse((value as Map)['date'] as String),
);
```

Pass this as `argumentsCodec`. Callbacks must handle null when appropriate.
Encoding validates and normalizes the callback output through JSON, matching the
default codec's supported history values. Decoding delegates to the callback;
errors invoke the existing parser fallback to the visible URI. Avoid secrets in
history payloads. Existing subclass codecs and serialized history version 3
remain unchanged.

## Validation record

See `doc/release-3.2.0-validation.md` for executed checks and remaining release
gates. CI configuration alone is not evidence that a matrix cell passed. Do not
publish until the required platform checks are recorded with SDK, platform,
command, outcome and limitations.

## Compatibility and rollout

- Version becomes 3.2.0; SDK constraints remain Flutter >=3.27.0 and Dart >=3.6.0.
- No existing constructor, string API or callback return type is removed.
- Applications may adopt each helper independently. No code generation is added.
- Changelog entries for 3.1.0 remain intact; 3.2.0 lists only additions and carried-forward guarantees.
- The minimal example is runnable with `flutter run -t lib/minimal.dart` from `example`.
- See `doc/platform-validation.md` for native/browser procedures and `doc/recipes.md` for the app recipes.
