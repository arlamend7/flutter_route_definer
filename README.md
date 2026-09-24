# route_definer

Explicit route definitions for Flutter's Router and Navigator: define a path once, read its parameters, check access before building a screen, and navigate with typed results.

The library provides:

- An instance-owned `RouterConfig` for URL-addressable pages, browser history and navigation-stack restoration.
- One ordered guard pipeline for authorization, redirects and asynchronous validation.
- Required loading, denied, not-found and error builders, with optional ready-made widgets.
- Current-route and stack inspection, optional bounded event history, and configurable diagnostics.
- Native Flutter page routes, typed pop results, custom factories and independent nested stacks.

Choose it when you want a small, explicit route table without code generation. Automatic shell/tab orchestration, wildcard matching and automatic URL composition across nested navigators are outside its scope.

**This checkout prepares an unpublished 3.0.0 release with breaking changes.** See [migration](MIGRATION.md) before upgrading an existing application.

## Contents

- [Install and check compatibility](#install-and-check-compatibility)
- [Run the example](#run-the-example)
- [Quick start](#quick-start)
- [Navigate and return results](#navigate-and-return-results)
- [Define paths and read route state](#define-paths-and-read-route-state)
- [Control access with guards](#control-access-with-guards)
- [Choose loading and failure pages](#choose-loading-and-failure-pages)
- [Set browser titles](#set-browser-titles)
- [Inspect routes, stack and history](#inspect-routes-stack-and-history)
- [Observe changes and enable diagnostics](#observe-changes-and-enable-diagnostics)
- [Configure the router and native pages](#configure-the-router-and-native-pages)
- [Restore navigation and encode arguments](#restore-navigation-and-encode-arguments)
- [Use independent nested navigators](#use-independent-nested-navigators)
- [Limitations and troubleshooting](#limitations-and-troubleshooting)
- [Resources and source layout](#resources-and-source-layout)

## Install and check compatibility

For this unpublished checkout, use a local path dependency. Replace the path with the location of your cloned repository:

```yaml
dependencies:
  flutter:
    sdk: flutter
  route_definer:
    path: ../flutter_route_definer
```

Run `flutter pub get`. Import the core API from `package:route_definer/route_definer.dart`; import `package:route_definer/default_pages.dart` separately if you want the optional page widgets. Do not import `src/` files.

| Requirement | Declared constraint | Local verification |
|---|---|---|
| Flutter | `>=3.27.0` | Flutter 3.41.6 |
| Dart | `>=3.6.0 <4.0.0` | Dart 3.11.4, bundled with that Flutter SDK |
| `meta` annotations | `^1.15.0` | Imported directly for compatibility with older Flutter SDKs |
| `web` runtime dependency | `>=0.4.0 <2.0.0` | Normal and minimum dependency resolutions are checked separately |

The declared SDK floor is not a claim that every compatible SDK/platform has been executed. Other SDK matrix cells and native-device gesture checks remain release gates. See [compatibility](doc/compatibility.md) and [the validation record](doc/validation.md) for results and limitations. Do not add a hosted `^3.0.0` dependency until that version is actually published.

## Run the example

From the repository root:

```sh
cd example
flutter pub get
flutter run -d chrome
```

The [example application](example/lib/main.dart) demonstrates sign-in redirects, denial, asynchronous failure/retry, typed results, unknown routes and a live **Inspect navigation** panel. Its included platform runner is web. Native applications need their own Flutter platform setup.

## Quick start

Paste this into `lib/main.dart` after adding the dependency. It has just two pages: tap **Open About** to navigate, then use the AppBar's back button to return.

```dart
import 'package:flutter/material.dart';
import 'package:route_definer/default_pages.dart' as default_router;
import 'package:route_definer/route_definer.dart';

void main() => runApp(MaterialApp.router(routerConfig: router.config));

final RouteDefinerRouter router = RouteDefinerRouter(
  loadingBuilder: (_) => const default_router.LoadingPage(),
  deniedBuilder: (_, __) => const default_router.DeniedPage(),
  notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
  errorBuilder: (_, __, retry) => default_router.ErrorPage(onRetry: retry),
  routes: [
    RouteDefiner<void>(
      path: '/',
      builder: (_, __) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => router.push<void>('/about'),
            child: const Text('Open About'),
          ),
        ),
      ),
    ),
    RouteDefiner<void>(
      path: '/about',
      builder: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('About')),
        body: const Center(child: Text('Hello!')),
      ),
    ),
  ],
);
```

The four page builders are required by the library; this example uses the supplied widgets. The router lives for the lifetime of this tiny app. If a widget owns your router instead, create it once in `initState` and call `router.dispose()` in `dispose`. Keep it outside `build`, and use a separate router for each navigation tree.

Run this exact [minimal example](example/lib/minimal.dart) from the repository:

```sh
cd example
flutter pub get
flutter run -d chrome -t lib/minimal.dart
```

Subsequent snippets use these imports and `router`. Add route definitions to its `routes` list and configuration arguments to its constructor where indicated.

## Navigate and return results

Use router methods for pages that should participate in URL synchronization and restoration:

| Call | Return value and behavior |
|---|---|
| `router.push<T>(location, arguments: ...)` | `Future<T?>`; appends one page and adds a browser-history entry. A normal pop returns its result. |
| `router.go(location, arguments: ...)` | `void`; rebuilds registered ancestors plus the destination and adds history. |
| `router.replace(location, arguments: ...)` | `void`; replaces the top page and current browser-history entry. |
| `router.pop<T>(result)` | `Future<bool>` from `Navigator.maybePop`; respects `PopScope` and pageless dialogs. `true` means handled, which can include a veto; inspect the stack/events to confirm a page was popped. |

To return a value, first add this item route to the quick start's `routes` list:

```dart
RouteDefiner<int>(
  path: '/items/:id',
  data: {'section': 'catalog'},
  guards: [
    (current) {
      current.state.pathInt('id');
      return const RouteDecision.allow();
    },
  ],
  builder: (_, state) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => router.pop<int>(state.pathInt('id')),
        child: const Text('Select this item'),
      ),
    ),
  ),
)
```

Then use an `async` button callback to open it and await the result:

```dart
final selected = await router.push<int>('/items/7');
if (selected != null) debugPrint('Selected $selected');
```

`RouteDefiner<T>` sets the native route's result type. Use the same `T` for `push<T>` and `pop<T>`. Flutter's `Navigator.of(context).pop<T>(result)` also works for the managed page. Removal, replacement, redirect away from an attempted destination, stack reset and router disposal complete pending library push futures with `null`. Browser Forward restores a page, not a previously completed Future.

`go('/users/42/edit')` includes `/`, `/users` and `/users/42` only when those ancestors are registered, then includes the final destination even if unmatched. `push` appends only the requested destination.

For an editor returning an `int`, wrap its content as follows:

```dart
const PopScope<int>(
  canPop: false,
  child: Text('Save your changes before leaving'),
)
```

Set `canPop` from application state and use Flutter's `onPopInvokedWithResult` for feedback. Explicit `go`/`replace` and browser-history updates are not pop attempts and do not ask `PopScope` for permission. Browser unsaved-change handling belongs to the application.

## Define paths and read route state

Patterns use literal segments and whole-segment parameters such as `/users/:id`. Matching is case-sensitive, preserves trailing slashes, and treats punctuation literally. There are no regex patterns, wildcards or optional segments.

The **first complete match in declaration order wins**. Put `/users/new` before `/users/:id` when the static route should take precedence. Partial matches do not hide complete matches. Identical/equivalent patterns such as `/users/:id` and `/users/:name` are rejected at registration with `ArgumentError`.

Generate links instead of interpolating unescaped values:

```dart
final fileRoute = RouteDefiner<void>(
  path: '/files/:name',
  builder: (_, state) => Text(state.requirePathParameter('name')),
);
final location = fileRoute.location(
  parameters: {'name': 'São Paulo/report.txt'},
  queryParameters: {'tag': ['work', 'draft']},
  fragment: 'details',
);
// Register fileRoute before navigating to location.toString().
```

`location()` returns a `Uri` and rejects missing, extra or empty path parameters. Parameters are decoded once when matching; an encoded slash stays inside its original segment. Dart URI normalization, including dot-segment normalization, still applies.

Builders, titles and guards receive `RouteState`:

| Member | Meaning |
|---|---|
| `uri` | Full URI, including query and fragment; external URI authority is retained. |
| `path`, `fragment` | Dart's encoded URI getters; use `Uri.decodeComponent` for display if appropriate. |
| `uriParams` | Decoded path parameters; `null` for unmatched locations. |
| `queryParams`, `queryParamsAll` | Read-only single-value and repeated-value query views. Use `queryParamsAll` when repetition matters. |
| `arguments` | Application payload; ordinary builder/guard state does not deep-copy it. |
| `requirePathParameter(name)` | Required string parameter, otherwise `FormatException`. |
| `pathInt(name)` | Required integer parameter, otherwise `FormatException`. |
| `argumentsAs<T>()` | Runtime-checked argument cast, otherwise `FormatException`. |

Validate required data in a guard to send validation failures through `errorBuilder`; an exception thrown in a screen builder remains a Flutter build error.

After registering the `/items/:id` route above, look it up without navigating:

```dart
final match = router.match('/items/42?tag=a&tag=b#details',
    arguments: {'source': 'lookup'});
assert(match.definition?.path == '/items/:id');
assert(match.state.pathInt('id') == 42);
assert(match.state.queryParamsAll['tag']!.length == 2);
```

Lower-level `RoutePattern('/items/:id').match(location)` returns parameter values or `null`. A pattern also exposes `parameters`, `signature`, `matchSegments` for already-decoded segments, and `location`. `parseRouteUri(location)` validates incoming locations without navigating. Malformed escapes or invalid path/query UTF-8 produce `FormatException`; your app remains responsible for accepted external hosts/schemes.

Custom `RouteDefiner.data` is application metadata, not authorization by itself. Read it in guards through `current.route.data`, or inspect its copied collection values through `router.currentRoute.data`.

## Control access with guards

`guards` is the only authorization/redirect pipeline. A `RouteGuard` is a function returning `RouteDecision` or `Future<RouteDecision>`:

- `allow()` continues; the screen builds only after every guard allows.
- `deny()` stops and uses `deniedBuilder` without building protected content.
- `redirect(location, arguments: ...)` stops and replaces the attempted destination.
- Throwing an exception stops and uses `errorBuilder`; optional `onError` receives a `RouteFailure` with error, stack trace and state.

### Authentication and sign-in recipe

Add `final signedIn = ValueNotifier(false);` before the quick-start router declaration, pass `refreshListenable: signedIn` to the router, and add these definitions to `routes`:

```dart
RouteDefiner<void>(
  path: '/account',
  guards: [
    (_) => signedIn.value
        ? const RouteDecision.allow()
        : const RouteDecision.redirect('/login'),
  ],
  builder: (_, __) => Scaffold(
    body: FilledButton(
      onPressed: () => signedIn.value = false,
      child: const Text('Sign out'),
    ),
  ),
),
RouteDefiner<void>(
  path: '/login',
  builder: (_, __) => Scaffold(
    body: FilledButton(
      onPressed: () {
        signedIn.value = true;
        router.replace('/account');
      },
      child: const Text('Sign in'),
    ),
  ),
),
```

Open the protected page with `router.go('/account')`. Sign-out triggers a fresh access check through the listenable and redirects back to login. If a widget owns this session and router, dispose `signedIn` after disposing the router. This local recipe does not authenticate against a server; enforce authorization on your backend too. Validate/allowlist return destinations if you accept them from query parameters.

### Asynchronous checks, timeout and cancellation

A reusable guard can receive application I/O as a dependency:

```dart
RouteGuard permissionGuard(Future<bool> Function() checkPermission) {
  return (current) async {
    final allowed = await checkPermission();
    current.cancellation.throwIfCancelled();
    return allowed
        ? const RouteDecision.allow()
        : const RouteDecision.deny();
  };
}
```

Add its returned function to a definition's `guards`. Set `resolutionTimeout: const Duration(seconds: 10)` on the router to bound the whole attempt; the default `null` has no timeout. A timeout produces a failure and ignores late results. Redirect cycles or chains beyond `redirectLimit` (default `5`) also fail.

Unrelated widget rebuilds reuse the current attempt. Removing or covering a pending page cancels it; returning to that covered pending page starts a new attempt. Completed checks remain valid until `refresh()`/`refreshListenable` or relevant definition/state changes. Call `router.refresh()` after changes that require access to be reevaluated.

`CurrentRoute` exposes `context`, `route`, `state`, `cancellation` and `isActive` for that attempt. `isActive` checks mounted context and cancellation, not global navigator focus or visibility. Use `cancellation.whenCancelled` to connect an HTTP client's cancellation facility. Dart cannot forcibly terminate arbitrary Futures. Do not retain the widget context or navigate imperatively from guards; return a redirect decision.

## Choose loading and failure pages

All four builders are required, even if your app expects a particular condition to be rare:

| Builder | When it runs | Inputs |
|---|---|---|
| `loadingBuilder` | While active guards are pending | `CurrentRoute` |
| `deniedBuilder` | A guard returns deny | `BuildContext`, `CurrentRoute` |
| `notFoundBuilder` | No complete route definition matches | `BuildContext`, `RouteState` |
| `errorBuilder` | Guard/navigation-resolution failure | `BuildContext`, `RouteFailure`, retry callback |

The optional `LoadingPage`, `DeniedPage` and `NotFoundPage` accept a `message`. `ErrorPage` requires `onRetry` and accepts `message` and `retryLabel`. They are neutral widgets with accessible status text; the retry action supports pointer, keyboard and semantics. They do not provide your application's Scaffold or localization automatically.

Replace quick-start builder arguments to use your own UI or customize the supplied pages:

```dart
loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
notFoundBuilder: (_, state) => Scaffold(
  appBar: AppBar(title: const Text('Page not found')),
  body: TextButton(
    onPressed: () => router.go('/'),
    child: Text('No page for ${state.path}. Go home'),
  ),
),
errorBuilder: (_, failure, retry) => default_router.ErrorPage(
  onRetry: retry,
  message: 'Unable to open this page',
  retryLabel: 'Try again',
),
```

Retry starts a new guard attempt; it does not repair an invalid location or recreate your service. `onError` runs once per reported attempt for application diagnostics. The provided error page hides exception details. Unknown locations use `notFoundBuilder`, while malformed incoming locations use controlled error handling; invalid programmatic `push`/`go`/`replace` input throws before changing the stack.

The import alias is your choice. `as default_router` follows Dart conventions; `as DefaultRouter` permits `DefaultRouter.ErrorPage(onRetry: retry)`.

## Set browser titles

Set a definition's `title` to the complete browser title:

```dart
RouteDefiner<void>(
  path: '/reports/:id',
  title: (state) => 'Report ${state.requirePathParameter('id')} — My app',
  builder: (_, __) => const Text('Report'),
)
```

The callback may return `String` or `Future<String>`. Missing, empty or failed titles fall back to the router's `appTitle` (default empty string). `appTitle` is not automatically prepended. The router manages browser-title observation, ignores stale asynchronous results, and keeps the underlying page title while dialogs are open. It does not set AppBar or native window titles.

## Inspect routes, stack and history

Retrieve metadata without a BuildContext:

```dart
Map<String, Object?> describeCurrentRoute(RouteDefinerRouter router) {
  final current = router.currentRoute;
  return {
    'id': current.id,
    'uri': current.state.uri,
    'path': current.state.path,
    'pathParameters': current.state.uriParams,
    'queryParameters': current.state.queryParamsAll,
    'fragment': current.state.fragment,
    'arguments': current.state.arguments,
    'definition': current.definition,
    'data': current.data,
  };
}
```

`currentRoute` is this instance's top **managed page**, including an attempted destination still loading, denied or showing an error. It is not proof that access was granted. Dialogs, bottom sheets and imperative pageless pushes do not become the managed current route. Inspect each nested router separately; the library does not automatically choose the active leaf across tabs/navigators.

| API | Contents and order |
|---|---|
| `router.routes` | Registered definitions, in matching precedence order. |
| `router.currentRoute` | Resolved `RouteSnapshot` for this router's current managed page. |
| `router.stack` | Read-only resolved snapshots, **bottom/root to top/current**. |
| `router.currentConfiguration.locations` | Existing lower-level URI/argument/ID stack used by Flutter restoration. |
| `router.history` | Optional retained `NavigationEvent` snapshots, **oldest to newest**. |

Add `historyLimit: 50` to the quick-start router to retain the newest 50 events. The default `0` disables retention. History includes activity involving pages that have already left the live stack. Bounds count events, not payload bytes or data retained by stream subscribers. Cancel unused subscriptions. It is cleared on disposal and is not persisted across reload or Flutter restoration.

```dart
final pages = router.stack;
for (final page in pages) {
  debugPrint('${page.id}: ${page.state.uri}');
}
final activity = router.history;
if (activity.isNotEmpty) {
  debugPrint('Latest action: ${activity.last.action.name}');
}
```

This explicit application logging prints URI values; use the built-in diagnostics below when you want its default redaction.

Events describe committed model changes and guard outcomes, not animation/render completion:

| Action | Meaning |
|---|---|
| `initialize`, `push` | Initial stack or one appended page. Guards may still be pending. |
| `pop`, `remove` | Successful managed pop, or Flutter-reported managed removal. Pops update immediately; later framework cleanup does not duplicate the event. |
| `replace`, `redirect` | Top/attempted destination replacement; the previous route remains available in the event. |
| `reset` | `go` replaced the canonical stack; no synthetic event per discarded page. |
| `restore` | External URI/history/restoration configuration. It cannot reliably distinguish browser Back, Forward or other updates. |
| `refresh` | Access/definition refresh, including `updateRoutes`; URI may be unchanged. |
| `guardResult`, `failure` | Valid completed guard outcome or reported resolution failure; retry can produce new events. |

Each event exposes `sequence`, UTC `timestamp`, `source`, `destination`, affected `route`, resulting `stack`, and applicable `guardIndex`, `guardOutcome`, `redirectLocation` or `failure`. A removal below the top leaves source/destination unchanged while `route` identifies the removed entry. Vetoed pops, dialogs and late cancelled guard results do not create false successful managed-navigation events.

Snapshot collection values are recursively copied and read-only. Opaque models/map keys remain application-owned references. `definition` is the original registration; use snapshot `data` for copied metadata rather than assuming `definition.data` is deep-frozen. Raw event/history data is **not** redacted by logging settings. See [inspection guarantees and event semantics](doc/route-inspection.md).

## Observe changes and enable diagnostics

The router is a `Listenable`. For current-route UI, this widget rebuilds on stack/refresh notifications:

```dart
Widget currentLocationLabel(RouteDefinerRouter router) => ListenableBuilder(
  listenable: router,
  builder: (_, __) => Text(router.currentRoute.state.uri.toString()),
);
```

For manual listeners, pair `addListener(callback)` with `removeListener(callback)`. Guard-only results/failures use the event stream instead:

```dart
// Add: import 'dart:async';
StreamSubscription<NavigationEvent> observeNavigation(RouteDefinerRouter router) {
  return router.events.listen((event) {
    debugPrint('${event.sequence}: ${event.action.name}');
  });
}
// Keep the returned subscription and cancel it when its owner is disposed.
```

`events` is asynchronous, broadcast and has no replay. Its event snapshot can differ from the router's newer live state by delivery time. Listening does not enable retained history; subscribing after initialization does not replay earlier activity. The stream closes on router disposal. The [example inspector](example/lib/widgets/navigation_inspector.dart) uses `StreamBuilder<NavigationEvent>`.

For built-in structured logs, add this argument to the quick-start router:

```dart
diagnostics: NavigationDiagnostics(
  logger: (message) => debugPrint('[navigation] $message'),
  includeParameters: false,
  includeArguments: false,
  includeData: false,
  includeErrorDetails: false,
),
```

`diagnostics` defaults to `null` (off). `const NavigationDiagnostics()` uses `debugPrint`. Logs contain action, source/destination, subject, stack and applicable guard/redirect/failure information. Default route labels use registered patterns; concrete URI values, arguments, metadata and exception messages are excluded. Each boolean explicitly opts into its category; `includeParameters` includes the full URI, path/query values and fragment. Error type is reported without its message/stack unless enabled. Registered patterns themselves are logged, so do not embed secrets in them.

A custom logger receives the formatted string, and logger exceptions do not change navigation outcomes. `NavigationDiagnostics.format(event)` applies the same formatting to an event you already hold; `NavigationEvent.toString()` is a value-free summary. Explicit logging works in any build: use `kDebugMode ? NavigationDiagnostics(...) : null` for development-only logs, importing `package:flutter/foundation.dart`. With history, logging and listeners all off, no event snapshot copying/formatting runs. No debug guard is needed to observe stack changes.

## Configure the router and native pages

Constructor settings, in addition to the required `routes` and four page builders:

| Setting | Default | Purpose |
|---|---|---|
| `initialRoute` | `'/'` | Initial location; a non-root platform entry takes precedence. |
| `appTitle` | `''` | Browser-title fallback. |
| `onError` | `null` | Report guard/resolution failures to your application. |
| `resolutionTimeout` | `null` | Optional duration for a complete guard attempt. |
| `redirectLimit` | `5` | Maximum redirect chain; must be at least 1. |
| `refreshListenable` | `null` | Recheck access when authentication or similar state changes. |
| `historyLimit`, `diagnostics` | `0`, `null` | Independent opt-ins for retention and logging. |
| `defaultRouteOptions` | Empty `RouteOptions()` | Inherited native page settings. |
| `routeFactory` | SDK `MaterialPageRoute<T>` | Global native route factory, including unknown/error pages. |
| `navigatorKey`, `observers` | New key, empty list | Access the native Navigator or add your own observers. |
| `restorationScopeId` | `null` | Navigator restoration scope; configure the app scope too. |
| `argumentsCodec` | `JsonRouteArgumentsCodec()` | Encode/decode restorable argument values. |
| `backButtonDispatcher` | Root dispatcher in `config` | Supply a child dispatcher for a nested router. |

A definition requires `path` and `builder`; `guards` defaults to an empty immutable list. `title`, `data`, `options` and `routeFactory` are optional. Definitions and their list/map containers are immutable; replace a table through `router.updateRoutes(newDefinitions)`. This validates the new table, refreshes access/content and updates titles. Existing native route transitions/options are fixed when that route is created; replace its page to change them.

`defaultRouteOptions` is merged with per-definition `options`; each non-null route value overrides its global counterpart. `RouteOptions.merge` exposes the same behavior. If neither supplies a value, the Material factory uses:

| Option | Material fallback |
|---|---|
| `maintainState` | `true` |
| `fullscreenDialog` | `false` |
| `allowSnapshotting` | `true` |
| `barrierDismissible` | `false` |
| `requestFocus` | `null` — defer to Flutter |

For a custom native route, add `import 'package:flutter/cupertino.dart';` to the quick-start imports and register this definition:

```dart
RouteDefiner<int>(
  path: '/picker',
  options: const RouteOptions(fullscreenDialog: true),
  routeFactory: <T>(settings, builder, options) => CupertinoPageRoute<T>(
    settings: settings,
    builder: builder,
    maintainState: options.maintainState ?? true,
    fullscreenDialog: options.fullscreenDialog ?? false,
  ),
  builder: (context, _) => CupertinoPageScaffold(
    child: Center(
      child: CupertinoButton(
        onPressed: () => Navigator.of(context).pop<int>(7),
        child: const Text('Choose 7'),
      ),
    ),
  ),
)
```

Open it with `router.push<int>('/picker')`. The same generic `DefinedRouteFactory` can be assigned globally. Always preserve the supplied `settings`, which carries the typed Page identity. Factories decide which options they support; use a `PageRoute` for the built-in title observation. `allowSnapshotting` controls Flutter transition snapshots, not OS previews. Theme transitions and reduced-motion behavior remain Flutter/application responsibilities.

## Restore navigation and encode arguments

Add `restorationScopeId: 'navigation'` to the quick-start router and `restorationScopeId: 'app'` to `MaterialApp.router`. The router serializes stack URIs, IDs and codec-encoded arguments. Screens must use Flutter's own restorable state primitives for forms/scroll positions. Guards and route definitions are not serialized; newly restored pages run their checks. Event history is not restored.

Use JSON-compatible arguments when possible. With the `/items/:id` route from [Navigate and return results](#navigate-and-return-results) registered:

```dart
final result = await router.push<int>(
  '/items/42',
  arguments: {'source': 'catalog', 'filters': ['recent']},
);
if (result != null) debugPrint('Returned $result');
```

Unsupported argument values fail before programmatic navigation. For custom model types, provide a codec that encodes JSON-compatible values and reconstructs models. This complete codec supports one model type plus `null`:

```dart
class ItemSelection {
  const ItemSelection(this.id);
  final int id;
}

class ItemArgumentsCodec extends RouteArgumentsCodec {
  const ItemArgumentsCodec();

  @override
  Object? encode(Object? arguments) {
    if (arguments == null) return null;
    if (arguments is ItemSelection) return {'itemId': arguments.id};
    throw ArgumentError('Expected ItemSelection');
  }

  @override
  Object? decode(Object? encoded) {
    if (encoded == null) return null;
    if (encoded is Map && encoded['itemId'] is int) {
      return ItemSelection(encoded['itemId'] as int);
    }
    throw const FormatException('Invalid item arguments');
  }
}
```

Set `argumentsCodec: const ItemArgumentsCodec()` and pass `arguments: const ItemSelection(42)` when navigating. A codec applies to every page/redirect, so support all payload types your app uses. Credentials/private data should stay out of URLs and serialized browser state.

Advanced integrations can inspect `RouteStack`/`RouteLocation` and use `RouteDefinerParser(argumentsCodec: ...)` to parse or restore `RouteInformation`. `router.config` wires this up automatically. Invalid external history falls back to its visible URI. These restoration objects are not a persistent navigation-event ledger.

## Use independent nested navigators

Create a distinct router for each child stack and mount `Router<RouteStack>.withConfig(config: child.nestedConfig)` inside a parent page. `nestedConfig` does not report a separate platform URL. Build the child before mounting the parent page, keep both instances outside `build`, and dispose both with their owner.

Given the quick-start router as the parent, this helper creates an independent child with its own required page choices:

```dart
RouteDefinerRouter createChildRouter(RouteDefinerRouter parent) {
  final dispatcher = parent.config.backButtonDispatcher!
      .createChildBackButtonDispatcher();
  final child = RouteDefinerRouter(
    initialRoute: '/child',
    backButtonDispatcher: dispatcher,
    loadingBuilder: (_) => const default_router.LoadingPage(),
    deniedBuilder: (_, __) => const default_router.DeniedPage(),
    notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
    errorBuilder: (_, failure, retry) =>
        default_router.ErrorPage(onRetry: retry),
    routes: [
      RouteDefiner<void>(
        path: '/child',
        builder: (_, __) => const Text('Child home'),
      ),
    ],
  );
  dispatcher.takePriority(); // When this child is the active navigation area.
  return child;
}
```

In a parent definition's builder, return `Router<RouteStack>.withConfig(config: child.nestedConfig)`, where `child` is the instance you created. Change dispatcher priority when changing active tabs. The app controls tab selection, widget retention and root-to-child URI mapping. This is not automatic shell routing, combined global route inspection or automatic branch restoration; see [nested navigation details](doc/navigation.md#nested-stacks).

## Limitations and troubleshooting

| Symptom or requirement | What to check |
|---|---|
| “Why is my path unknown?” | Case, trailing slash, complete segment count and registration order. Partial final destinations use `notFoundBuilder`. |
| “Missing required builder arguments” | Supply all four page builders; optional widgets are never installed implicitly. |
| “Guards run again unexpectedly” | Keep the router outside `build`; inspect refresh notifications and definition/argument changes. |
| “A page stays loading” | Ensure the guard's Future completes or set `resolutionTimeout`. Cancellation cannot stop I/O without client cooperation. |
| “Sign-out leaves protected content” | Connect session changes to `refreshListenable` or call `refresh()`. |
| “No navigation logs/history” | Both default off. Set `diagnostics` and/or positive `historyLimit`; stream subscriptions have no replay. |
| “A dialog is not the current route” | Inspection covers managed pages. Use your own NavigatorObserver for pageless UI. |
| “A child route is missing from the root stack” | Inspect the child router; independent stacks are not aggregated. |
| “Arguments fail after reload” | Use JSON values or a codec covering every payload type; restored data may not have its original Dart type without a codec. |
| “PopScope did not prevent browser Back or go” | Those replace configuration rather than asking Navigator to pop. |
| “Custom route breaks updates/results” | Preserve Page settings and match result types. Use router methods to replace managed pages. |
| “Browser title differs from AppBar” | Route titles update the browser only; create AppBar/window titles explicitly. |

Web uses Flutter's default hash URL strategy unless your application changes it. Path URLs require Flutter URL-strategy setup and a host rewrite to `index.html`, plus a correct base href for subdirectory hosting. The library does not configure a server. Native app/universal links require platform manifests, domain association and device testing. See [platform setup](doc/navigation.md#platform-setup).

Tests of Flutter callbacks do not verify physical Android predictive-back or iOS swipe-back gestures. Native builds, standalone design-package integration and browser coverage outside executed Chrome checks remain limited; consult the validation record. Events do not expose the browser's complete history, gesture progress, completed animations, pageless activity or every application failure. Do not imperatively replace managed native routes outside the router API or force-remove/pop the last native route from a root-only stack.

Version 3 removes static `AppRouter`, `GlobalRouteDefiner`, named-route adapters, `isAuthorized`, `beforeEnter`, class-based guard checks and duplicate title callbacks. These are not compatibility aliases. Follow [MIGRATION.md](MIGRATION.md); existing modern `RouteDefinerRouter` methods, `currentConfiguration`, `match` and Listenable APIs remain available alongside inspection.

## Resources and source layout

- [Minimal quick start](example/lib/minimal.dart), [full example application](example/lib/main.dart) and [navigation inspector](example/lib/widgets/navigation_inspector.dart)
- [Inspection investigation, guarantees and event semantics](doc/route-inspection.md)
- [Platform setup, restoration and custom routes](doc/navigation.md)
- [Compatibility](doc/compatibility.md), [executed validation](doc/validation.md) and [pub points / CI findings](doc/pub-score.md)
- [Migration](MIGRATION.md), [changelog](CHANGELOG.md), [contribution/release checks](CONTRIBUTING.md) and [security reporting](SECURITY.md)
- [Performance measurements and their scope](doc/performance.md)
- [Published API reference](https://arlamend7.github.io/flutter_route_definer/route_definer/) — may describe the preceding release. Run `dart doc --output build/api` for the API in this checkout.

The public libraries are `lib/route_definer.dart` and the optional `lib/default_pages.dart`. Implementation folders group `routing`, `guards`, `inspection`, `titles` and `default_pages`; tests follow the same responsibilities. Inspection/history/diagnostics need no separate logging or tracking package. The direct `meta` dependency supplies annotations without relying on Flutter to re-export them.
