# Migrating to 3.0

This is an unpublished breaking release. It removes overlapping APIs and compatibility wrappers. Flutter >=3.27 and Dart >=3.6 are declared requirements; see [executed validation](doc/validation.md) before release.

## One setup

Create a `RouteDefinerRouter`, pass its `config` to `MaterialApp.router`, keep it outside `build`, and dispose it with its owner. Configure everything directly on the router. Follow the complete [quick start](README.md#quick-start) or [runnable example](example/lib/main.dart).

| Removed API | Replacement |
|---|---|
| Static `AppRouter` and `GlobalRouteDefiner` | One explicitly owned `RouteDefinerRouter` |
| Named-route callbacks and `Navigator.pushNamed` integration | `router.push<T>`, `go`, `replace`, `pop<T>` |
| `isAuthorized`, `beforeEnter`, class-based `RouteGuard.check` | Function-based `guards: [...]` returning `RouteDecision` |
| `current.redirect(...)` and thrown redirects | Return `RouteDecision.redirect(...)` |
| `RouteDecision.error(...)` | Throw an exception; handle it through `errorBuilder` and `onError` |
| `titleBuilder` and zero-argument `title` | `title: (state) => ...`, synchronous or asynchronous |
| Automatic app/page title formatting | Return the complete title; `appTitle` is only a fallback |
| Public `TitleObserver` and browser updater | Automatic internal title management |
| `RouteLoaderWidget` | Internal guard execution; configure `loadingBuilder` |
| Implicit loader/denial/error screens | Required `loadingBuilder`, `deniedBuilder`, `notFoundBuilder`, `errorBuilder` |
| `onUnknownRoute` returning a native route | `notFoundBuilder` returning a widget |
| Multiple matching/state helpers | `router.match(location, arguments: ...)` returns a record with `definition` and `state` |
| Legacy state constructors | `RouteState(Uri, ...)` |

The old names have no forwarding aliases. Import only the public libraries; source files have moved into `routing`, `guards`, `titles` and `default_pages` folders.

## Explicit page choices

The four builders are required even when you want the supplied views. Opt in through a separate import:

```dart
import 'package:route_definer/default_pages.dart' as default_router;

final router = RouteDefinerRouter(
  routes: routes,
  loadingBuilder: (_) => const default_router.LoadingPage(),
  deniedBuilder: (_, __) => const default_router.DeniedPage(),
  notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
  errorBuilder: (_, failure, retry) => default_router.ErrorPage(onRetry: retry),
);
```

Return your own widgets wherever the app needs a different design or behavior. The ready-made widgets accept display text for localization; the error widget requires a retry action and does not show exception details. An import prefix of `DefaultRouter` also supports the spelling `DefaultRouter.ErrorPage(...)`; lowercase `default_router` follows Dart's lint convention.

## One guard pipeline and one title resolver

```dart
RouteDefiner<void>(
  path: '/account',
  title: (state) => 'Account',
  guards: [
    (current) => signedIn
        ? const RouteDecision.allow()
        : const RouteDecision.redirect('/login'),
  ],
  builder: (_, __) => const AccountPage(),
);
```

Guards run in order. Denial, redirect and exceptions stop the chain and prevent protected page construction. Throwing an exception displays `errorBuilder`, which receives a retry callback. Removed or covered pending pages ignore late results. Connect your I/O cancellation to `current.cancellation`; connect authentication changes to `refreshListenable` or call `router.refresh()`.

## Behavior to review

- The first **complete** pattern match wins in declaration order. Literal punctuation has no regex meaning. Matching is case-sensitive and trailing slashes are significant. Ambiguous parameter patterns are rejected. Partial destinations use `notFoundBuilder`.
- URI state and definition collections are immutable. Use `updateRoutes` to replace definitions. Full URIs retain repeated query values and fragments; generated path parameters are encoded safely.
- Router arguments must round-trip through `RouteArgumentsCodec`. The default is JSON; model objects require a custom codec when their types must survive restoration.
- Match `RouteDefiner<T>` with `push<T>` and `pop<T>`. Removal, replacement, reset and disposal complete pending library push futures with `null`.
- `DefinedRouteFactory` is one generic callback type for global and route-specific overrides: `<T>(settings, builder, options) => CupertinoPageRoute<T>(settings: settings, builder: builder)`. Always preserve settings. The global factory also applies to not-found and error pages.
- Use `PopScope<T>` for native back veto. Explicit stack changes and browser history changes do not invoke a pop veto. Set restoration scope IDs on both the app and router when restoration is wanted.

See [navigation details](doc/navigation.md), [compatibility](doc/compatibility.md) and [release checks](CONTRIBUTING.md).
