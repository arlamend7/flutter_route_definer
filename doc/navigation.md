# Navigation integration

## Platform setup

Use `MaterialApp.router(routerConfig: router.config)` for full Router integration. A non-root platform entry URI takes precedence over `router.initialRoute`. Cold entry builds registered ancestors; warm external URI changes rebuild that canonical stack. In history restoration, stored page IDs preserve existing pages where possible. External history state is validated and falls back to its visible URI if invalid.

The default Flutter web URL strategy uses hashes. To use path URLs, add `flutter_web_plugins` as an SDK dependency, call `usePathUrlStrategy()` before `runApp`, and configure your server to serve `index.html` for application paths. Set the deployment base href when hosting under a subdirectory. The library does not configure your server. See [Flutter URL strategies](https://docs.flutter.dev/ui/navigation/url-strategies).

For Android and iOS, configure application links/universal links, domain association and platform manifests. Flutter's native deep-link handling is enabled by default from 3.27; avoid enabling a second deep-link plugin handler for the same events. See [Flutter deep linking](https://docs.flutter.dev/ui/navigation/deep-linking) and the [default flag change](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change). Validate external URI hosts/schemes against your application's allowlist before trusting their contents.

`Navigator` and platform page routes own gestures and animations. This package uses `onDidRemovePage`, typed `Page.onPopInvoked`, and `Navigator.maybePop`; it does not override predictive-back gestures or install legacy `WillPopScope`. Put `PopScope<T>` around an editable screen and match the route's result type. Physical Android predictive-back and iOS swipe-back checks are part of the release checklist, separate from widget tests.

Browser Back/Forward supplies a restored configuration. It is not equivalent to a `Navigator.maybePop` attempt, and `PopScope` does not veto it. Do not assume it protects a document from browser navigation or refresh; implement application/browser unsaved-change handling separately. `router.pop` changes the current history entry; browser Back/Forward follows the browser's entries.

## Restoration and arguments

Set both `MaterialApp.router(restorationScopeId: 'app', ...)` and `RouteDefinerRouter(restorationScopeId: 'navigation', ...)`. Screens must use Flutter's restorable state primitives for their own form/scroll state. The router serializes stack URIs, page IDs and arguments. Route definitions and guard results are not serialized; newly restored pages run checks.

Router arguments must round-trip through `RouteArgumentsCodec`. The default codec uses JSON serialization. Prefer JSON primitives, lists and maps; domain objects need a custom codec if their Dart types must survive restoration. Encode into JSON-compatible data and reconstruct your model in `decode`. Invalid custom history state falls back to the visible URI. Keep credentials and private payloads out of URLs and history state; store IDs and reload protected data after authorization.

## Route factories, themes and transitions

`DefinedRouteFactory` is a generic function returning `Route<T>`. Set `router.routeFactory` to customize all pages, including unknown and error pages, or override it with `RouteDefiner.routeFactory`. Preserve the supplied `settings`, which is a `Page<T>`. Dropping it breaks page identity and Navigator's page lifecycle. Return a `PageRoute` when browser-title observation is needed.

```dart
RouteDefiner<int>(
  path: '/picker',
  builder: (_, __) => const PickerScreen(),
  routeFactory: <T>(settings, builder, options) => CupertinoPageRoute<T>(
    settings: settings,
    builder: builder,
    maintainState: options.maintainState ?? true,
    fullscreenDialog: options.fullscreenDialog ?? false,
  ),
);
```

The default factory uses the SDK's `MaterialPageRoute<T>` and passes through `RouteOptions`. Route-specific non-null options override global options. `allowSnapshotting` controls transition snapshots, not operating-system previews. Factories choose how to apply options and reduced-motion preferences. Changing definitions rechecks and updates content; a route's transition type/options are fixed when its native Route is created, so replace the page to change them.

Flutter 3.47 introduces opt-in `material_ui` and `cupertino_ui` packages. For apps using those libraries, provide a route factory from the same design package as the app and choose the required loading/denied/not-found/error builders. Public extension points use `Widget`, `Route` and `RouteSettings`, avoiding a public `MaterialPageRoute` requirement. SDK Material remains the default to retain older Flutter compatibility. The standalone-package combination is provisional until its own integration test runs. See [Flutter's migration guidance](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui).

## Nested stacks

Each `RouteDefinerRouter` owns one Navigator. Create a separate instance for each independent nested stack. Mount `Router<RouteStack>.withConfig(config: child.nestedConfig)` under a parent Router; `nestedConfig` intentionally has no platform URL provider/parser. Create a `ChildBackButtonDispatcher` from the parent's dispatcher, pass it as `backButtonDispatcher`, and call `takePriority()` when that child is active. Keep inactive tab widgets in an `IndexedStack` to retain their state, and dispose routers when their owner is disposed.

This is independent nested navigation, not automatic URL composition, branch restoration or tab orchestration. The application controls tab selection, dispatcher priority and how a root URI maps to a child's location. For shell routing managed for you, evaluate a higher-level router.

## Titles, accessibility and errors

The router manages one internal title observer. `RouteDefiner.title(state)` resolves the complete browser title for the active page; it may be asynchronous. `router.appTitle` is only the fallback for missing, empty or failed titles. Dialogs retain the underlying page title. Removed/replaced pages and outdated asynchronous title successes/errors cannot overwrite the current title. Native targets use a no-op browser title updater; set AppBar/native window titles in your app.

All four page builders are required. The optional widgets in `package:route_definer/default_pages.dart` use live-region semantics; `ErrorPage` Retry has pointer, keyboard and semantic actions. Choose or replace these widgets for localization, visual design and your application's accessibility requirements. Screen focus comes from Flutter and `RouteOptions.requestFocus`; do not override it just to change a browser title.

A guard timeout or exception leaves loading, prevents page construction and invokes `onError` once for that attempt. Retry starts a fresh attempt. The library does not log arguments or exceptions by default. A malformed incoming location produces a controlled error page; invalid programmatic `push/go/replace` arguments fail before changing the stack. Errors thrown by your screen builder remain ordinary Flutter build errors.

## Inspection and diagnostic scope

Use `router.currentRoute`, `router.stack`, `router.events` and opt-in `router.history` to inspect this router’s managed pages. Dialogs and independent child stacks are separate. See [the inspection guide](route-inspection.md) for action semantics, snapshot guarantees and configurable logs. Browser history updates are recorded as `restore`; they are not labeled Back or Forward without reliable evidence.
