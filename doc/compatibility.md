# Compatibility and validation

Research/implementation date: **2026-09-23**. Version 3.0.0 is prepared in this checkout and is not published by this task.

## SDK and dependency policy

The package declares Flutter **>=3.27.0**, Dart **>=3.6.0 <4.0.0**, and `web` **>=0.4.0 <2.0.0**. The floor includes typed pop/page-removal APIs and the MaterialPageRoute options used here; it replaces the incorrect Flutter 1.17 / Dart 3.0 claim in 2.x. `web` 0.3 is excluded because it did not compile on the examined current toolchain.

| SDK | Dart | Status in this implementation session | CI obligation |
|---|---|---|---|
| Flutter 3.27.0 | 3.6.0 | Declared floor; not executed locally | Resolve/analyze/test with newest and downgraded dependencies; JS/Wasm builds and browser checks |
| Flutter 3.32.8 | 3.8.1 | Representative intermediate; not executed locally | Newest/downgraded analysis and tests |
| Flutter 3.41.6 | 3.11.4 | Executed locally on macOS arm64 | Newest/downgraded analysis and tests |
| Flutter 3.47.5 | 3.13.4 | Current stable in the official release manifest examined; not executed locally | Newest/downgraded analysis/tests, JS/Wasm browser checks, docs and publication dry run |

The official Google Storage SDK archive requests for both 3.27.0 and 3.47.5, and a fresh manifest request, returned HTTP 404 in this environment. Those cells remain **provisional**, not passing. The exact-version CI jobs are release gates. They must run successfully before publishing; source/API inspection is not a substitute for compilation. The [Flutter SDK archive](https://docs.flutter.dev/install/archive) is the authoritative version reference.

The package has one non-SDK runtime dependency, `web`; test/lint packages are development dependencies. Maintain the oldest SDK job and test `flutter pub downgrade` independently from normal resolution. Updating the SDK floor is a major-version change under this project's policy. No blanket promise is made for future unreleased SDKs.

## Relevant Flutter changes

- [Navigator page APIs, Flutter 3.24](https://docs.flutter.dev/release/breaking-changes/navigator-and-page-api): the delegate uses `onDidRemovePage`, while the typed Page callback collects pop results.
- [Typed PopScope, Flutter 3.24](https://docs.flutter.dev/release/breaking-changes/popscope-with-result): `router.pop` delegates to `maybePop`; tests cover veto and results.
- [Removed-route futures, Flutter 3.32](https://docs.flutter.dev/release/breaking-changes/navigator-complete-route): library `push` completers finish on replacement/reset/disposal without depending on the older framework's removal-future behavior. Direct imperative Navigator futures still follow that SDK's behavior.
- [Android default transitions, Flutter 3.38](https://docs.flutter.dev/release/breaking-changes/default-android-page-transition): the default uses Flutter's page route and theme; it does not copy transition timing or predictive-back internals.
- [Transition-builder decoupling, Flutter 3.44](https://docs.flutter.dev/release/breaking-changes/decouple-page-transition-builders): no direct dependency on the moved Cupertino transition builder is introduced.
- [Standalone design libraries, Flutter 3.47](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui): custom Route factories and neutral public extension points permit integration without requiring these packages for older SDK users. Standalone Material/Cupertino runtime behavior remains unverified.
- [Full RouteInformation URI](https://docs.flutter.dev/release/breaking-changes/route-information-uri): the parser uses `uri`, preserving query and fragment information.

## Platform evidence

| Target | What was verified | Remaining validation |
|---|---|---|
| Web JavaScript | Release compilation; headless Chrome URL/title/history/back/forward/reload/direct entry/typed result/redirect checks | Firefox, Safari, hosted path strategy and assistive technology |
| WebAssembly | Separate release build and actual Wasm execution in Chrome, with the same browser assertions | Other supported Wasm browsers and production hosting headers |
| Android | Flutter widget tests of Navigator/PopScope behavior | Device build, app links, predictive-back preview/commit/cancel |
| iOS | Typed Cupertino factory in widget tests | Device build, universal links and swipe-back gestures |
| macOS/Windows/Linux | Shared Dart/widget code and native title stub; macOS hosts the tests | Target application builds, window/focus behavior and native link setup |

A build is not a platform interaction test. CI's Linux host is not evidence of a Linux desktop application test. Native physical-platform and standalone-design-package checks remain release checklist items, not claimed successes.

## Reproducing validation

See [the validation record](validation.md) for executed results and [CONTRIBUTING.md](../CONTRIBUTING.md) for exact commands and the browser harness. Unit/widget regressions cover authorization rejection and exceptions, redirects, cancellation, retry, immutable URI state, page reuse, typed results, restoration, unknown routes, title races, independent routers and nested back dispatch. The example has its own sign-in/result/retry test. Browser checks use isolated Chrome profiles and assert `dart.tool.dart2wasm` for the Wasm run.

The release workflow reuses validation on the tagged commit and verifies tag/pubspec/changelog consistency before the OIDC publish job. Documentation deployment only follows successful validation of a master push and builds the same commit.
