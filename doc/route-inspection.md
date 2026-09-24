# Route inspection, event history and diagnostics

## Investigation before implementation

The existing `RouteDefinerRouter.currentConfiguration` returns a `RouteStack` containing `RouteLocation` objects in bottom-to-top order. Each location contains its URI, arguments and page ID. The last location is the router's current managed page. `router.match(location, arguments: ...)` supplies its `RouteState` and matching `RouteDefiner`; custom metadata is available as `definition.data`. Guards already receive these through `CurrentRoute`, but that object describes a guard attempt and holds a widget context, so it is not suitable as a long-lived inspection object.

The router already implements `Listenable` through `ChangeNotifier`: `addListener`/`removeListener` observe stack, route-table and access refresh changes. Registered definitions, stack lists and parameter maps are structurally read-only. Existing argument objects and nested custom metadata remain application-owned, rather than deep immutable values.

Missing pieces were a direct current-route inspection API, resolved stack snapshots, an event history that survives pop/replacement, and built-in configurable diagnostics. `observers: [...]` already accepts Flutter Navigator observers, which can observe native routes/dialogs but cannot explain guard outcomes or reliably identify the intent of declarative changes such as `go` and redirects. A debug guard alone misses completed stack mutations. Also, the existing stack removed a popped entry only after its outgoing transition finished; the typed page callback can identify a successful pop sooner and distinguish it from removal.

The compatible solution keeps existing APIs and adds instance-level snapshots and a single optional event mechanism. It uses the router's mutations, typed Page pop callback, a native removal observer and the existing guard lifecycle. The observer handles SDKs that do not call `onDidRemovePage` for `removeRoute`; duplicate notifications are ignored. No global registry, extra dependency, polling or second guard API is needed. History and logging are off by default. The scope is managed pages belonging to one router, not every route visible anywhere in the application or the browser's complete session history.

## Current route and stack

```dart
final current = router.currentRoute; // RouteSnapshot, scoped to this router.
final state = current.state;

state.uri;             // Full URI, including query and fragment.
state.path;            // Concrete path (Dart Uri's encoded representation).
state.uriParams;       // Decoded path parameters; null if unmatched.
state.queryParams;     // Single-value view.
state.queryParamsAll;  // Every value for repeated keys.
state.fragment;
state.arguments;
current.id;            // Stable managed page identity.
current.definition;    // Original RouteDefiner, or null if unmatched.
current.data;          // Snapshot of definition.data.

final pages = router.stack; // Bottom/root first, current/top last.
```

`currentRoute` means the top **managed page of this router**. The attempted destination is current even while loading, denied or displaying a navigation error; inspecting it is not proof that its guards allowed access or its screen was built. A dialog, modal bottom sheet or imperative pageless push does not become the managed current route. Each nested router reports only its own stack. The app chooses which child is active; the root does not recursively select a leaf across tabs/navigators. Existing `observers: [...]` can observe Flutter routes and dialogs when that separate view is needed.

These existing APIs remain available:

```dart
final location = router.currentConfiguration.locations.last;
final resolved = router.match(location.uri.toString(), arguments: location.arguments);
final definition = resolved.definition;
final state = resolved.state;
```

`currentConfiguration` is the lower-level URI/ID/argument configuration used by Flutter restoration. `routes` is the registered definition table, not the live stack. `CurrentRoute` is the context/cancellation object supplied to one guard attempt, not a global active-route accessor.

The new lists, state parameter maps and snapshot collection payloads are read-only. Argument and metadata maps/lists/sets are recursively copied (including cycles); mutating an original collection later does not change a captured snapshot. Collection copies preserve values, not every specialized collection subtype. Arbitrary model objects and map keys remain application-owned references because Dart cannot universally clone or freeze them. Use immutable domain models for reliable historical values. `definition` intentionally retains the original registered object, including its callbacks; use `snapshot.data` for copied metadata rather than `snapshot.definition.data`. Snapshots have no BuildContext or native Route field; the retained definition still holds application callbacks/closures.

## Observe changes

The existing Listenable API still works for managed-stack changes and refreshes:

```dart
void changed() {
  final current = router.currentRoute;
  final stack = router.stack;
  // Update application state using these snapshots.
}
router.addListener(changed);
// When the owner is disposed:
router.removeListener(changed);
```

For individual events, including guard outcomes and failures:

```dart
final subscription = router.events.listen((event) {
  final action = event.action;
  final source = event.source;
  final destination = event.destination;
  final subject = event.route;
  final resultingStack = event.stack;
  // Update an inspector, telemetry adapter or application-owned diagnostic UI.
});
// When the observer is disposed:
await subscription.cancel();
```

This is an asynchronous broadcast stream, without replay. It does not enable retained history. Subscribe before the operations you need to observe; stream callbacks receive the event's captured state, which may be older than the router's live state if several operations happen before delivery. It closes when the router is disposed. Existing `addListener` notifications do not fire solely for guard-result/failure events, so use `events` for those. `StreamBuilder<NavigationEvent>` is useful for inspectors; the [runnable inspector](../example/lib/widgets/navigation_inspector.dart) demonstrates it.

## Optional bounded history

Pass `historyLimit: 50` to `RouteDefinerRouter` to retain the newest 50 events. The default `0` retains nothing. `router.history` returns a read-only snapshot ordered **oldest to newest**; its last entry is the most recent event. Event sequences increase as events are captured and timestamps are UTC. A sequence is not a browser history index.

Each event contains its action, source and destination managed pages, affected `route`, resulting stack, and applicable guard outcome/index, redirect target or failure. History counts all these event kinds, not only visited URLs. A popped/replaced page can appear in history after leaving the stack. Bounds apply to event count, not payload bytes: large arguments and stacks still cost memory. Paused stream subscriptions and other consumer-owned buffers are not bounded by historyLimit; cancel unused subscriptions. History/event streams contain unredacted data; logging's redaction options do not redact them. History is cleared on router disposal and is not serialized into browser history or Flutter restoration. Reload starts a new event history. Activity while history, logging and event listeners are all disabled is not reconstructed.

| Trigger | Stack and event behavior |
|---|---|
| Construction | Canonical initial stack; `initialize` when tracking/logging is enabled. A later stream subscription does not replay it. |
| `push` | Adds one managed page; `push` records previous/current pages and the resulting stack. Guards may still be pending. |
| Successful managed pop | Removes that page immediately when the typed Page callback confirms success; one `pop`, without waiting for the outgoing animation. Typed results still complete normally. |
| Pop veto, pageless/dialog pop | No managed-stack event or fabricated successful pop. |
| `replace` | Replaces the top entry; one `replace`, retaining the old top as `source`. Framework cleanup does not generate extra removal events. |
| `router.remove(snapshot.id)` | Removes a managed page declaratively on every supported SDK, completes its pending push with null, and records one `remove`. Unknown IDs and removal of the sole remaining page return false without an event. |
| Imperative removal of a managed page on SDKs that allow it | `remove` when Flutter reports removal; `route` identifies the removed page. Removing below the top leaves source/destination at the same active page. |
| Guard redirect | `guardResult` with redirect outcome, followed by `redirect` when replacement commits. Redirect loops/limits become `failure` events. |
| `go` | Rebuilds registered ancestors and the final destination; one `reset`, not synthetic pop/push events for every replaced page. |
| External URI/history/restoration update | One `restore` with the resulting stack, retaining matching page IDs. The callback does not reliably identify Back versus Forward, reload, deep link or other configuration updates. |
| `refresh` / `updateRoutes` / refresh listenable | `refresh`, followed by outcomes of any re-run guards. URI/stack size need not change. |
| Completed valid guard | `guardResult` for each executed guard, with its zero-based index and allow/deny/redirect outcome. Later guards do not run after a terminal result. |
| Guard exception, timeout, navigation-resolution failure | One `failure` per reported attempt; retry can produce new outcomes. Screen-builder exceptions remain ordinary Flutter errors. |

Rejected programmatic input throws before mutation and is not recorded as a completed navigation. Late results from cancelled, covered or removed attempts are ignored. These events describe model changes and resolved checks, not completed animations, gesture progress or completed rendering. Flutter 3.27/3.32 reject native `Navigator.removeRoute` for declarative pages; use `router.remove(id)` for portable removal. The extra native-removal integration is tested on 3.41/3.47. Direct imperative replacement of a managed native Route outside the router's API is not a supported way to change its declarative stack. Use router APIs; pageless activity can be observed separately with Flutter's NavigatorObserver. Force-removing or force-popping the last native route from a root-only stack is unsupported.

## Built-in diagnostics

Enable `diagnostics: const NavigationDiagnostics()` on the router for `debugPrint` output, or customize it:

```dart
RouteDefinerRouter(
  // ...existing routes and required page builders...
  historyLimit: 50, // Optional, independent of logging.
  diagnostics: NavigationDiagnostics(
    logger: (message) => debugPrint('[navigation] $message'),
    includeParameters: false,   // Concrete URI, path/query values and fragment.
    includeArguments: false,
    includeData: false,
    includeErrorDetails: false, // Exception messages and stack traces.
  ),
);
```

Each log is a JSON line containing action, source, destination, subject and resulting stack, plus guard/redirect/failure details when present. By default, route labels are registered patterns such as `/items/:id`; unmatched concrete paths and redirect destinations are redacted. Registered patterns themselves are logged and must not contain secrets. No payload `toString` is called merely to log a redacted field. Error type is included, but its message/stack requires `includeErrorDetails`. The custom logger receives only the formatted/redacted string. `NavigationEvent.toString()` also omits sensitive values. Exceptions from logging callbacks are ignored so logging cannot turn an allowed route into a failure.

Logging is off when `diagnostics` is null, including in release mode. Explicitly enabling it enables it in any build; use `kDebugMode ? NavigationDiagnostics(...) : null` for development-only output, as the example does. When no history, logger or stream listener is enabled, event capture returns before timestamps, matching, snapshot copying or formatting. No separate logging/tracking package is used; `meta` is declared directly for annotations and is already a Flutter dependency.

## Verification and limits

Focused unit/widget tests exercise metadata/collection snapshots, stack order, immediate and single pop reporting, removal below the top, replacement/reset, restored arguments and identities, bounded/disabled history, asynchronous observation and disposal, nested/dialog scope, terminal redirects, loop failures, denial/retry/cancellation, and diagnostic redaction/custom loggers. The browser harness checks actual current-route snapshots, resulting stacks, `restore` on browser Back/Forward, fresh history after reload, pop/replacement/redirect events and redacted logging in JS and Wasm.

The local SDK remains Flutter 3.41.6. The other SDK matrix cells and native physical gestures remain release gates. These APIs do not enumerate the browser's entire history, aggregate independent navigators, capture pageless UI, report animation completion or observe arbitrary application failures.
