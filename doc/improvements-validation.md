# Routing improvements: validation record

Validated locally on 2026-09-27/28 with Flutter 3.47.5, Dart 3.13.4, macOS arm64. This record covers the working-tree improvements, not a published release or a completed remote CI run.

## Implemented behavior

- Guard refresh keeps previously authorized widget state while hiding it from painting, hit testing, focus and semantics and disabling tickers. Denial/error and changed definition/URI/arguments discard it. Retained timers/subscriptions remain application-owned.
- `pushRoute` infers its result type from the exact registered definition. `goRoute`/`replaceRoute` share registration and location validation. Shadowed and stale definitions fail before navigation changes.
- `routeWarnings` lazily reports complete shadowing without altering declaration-order matching.
- Three reproducible random seeds execute 100 navigation operations each, combining pushes, replacement, reset, removal, pop, refresh, restoration and late guard completion. They check stack contents, unique IDs, result completion and unauthorized content.
- Runnable recipes cover allowlisted login-return destinations, retained independent tabs with active-child back dispatch, and dirty-form confirmation.
- Disposable native fixtures and shared browser assertions are wired into iOS/Android and Firefox/WebKit CI jobs. A compile-time API check is added to every existing SDK/dependency matrix cell.

## Executed checks

| Check | Result |
|---|---|
| Library tests, normal dependencies | 73 passed |
| Library tests, minimum dependencies (including web 0.4.0) | 73 passed |
| Static analysis with normal and minimum dependencies | No issues |
| Example tests, normal dependencies | 5 passed |
| Compile-time typed API fixture | Integer inference accepted; incompatible String return rejected |
| iOS simulator integration | Passed on iPhone 17 Pro, iOS 26.4 |
| JavaScript release build and Chrome | 20 shared assertions passed, Chrome 151.0.7922.109 |
| Wasm release build and Chrome | 20 shared assertions passed; actual Wasm selection asserted |
| JavaScript release build and Playwright WebKit | 20 shared assertions passed, WebKit 26.6 |
| Browser startup harness | 4 tests passed |
| API documentation | 0 warnings, 0 errors |
| Isolated package publication dry run | 0 warnings; nothing published |
| Pinned pana 0.23.19 | 160/160 points, including generated documentation |
| Modified Dart formatting / diff whitespace | Clean |
| Workflow YAML | Parsed successfully |

The native integration test verifies typed results, a Cupertino edge-drag, dirty-form back veto, and an incoming Flutter platform route message. These are native-runtime checks, not proof of all OS gesture or link-association behavior. The example includes Cupertino icon assets.

Local raw reports are in ignored `build/`: `unit-validation.log`, `minimum-validation.log`, `example-validation.log`, `native-final-validation.log`, `chrome-js-validation.json`, `chrome-wasm-validation.json`, `webkit-validation.json`, `package-validation.log`, and `pub-score-current.json`.

Normal dependency resolution was restored after the downgrade check. The package candidate was copied outside the Git repository so inherited `build/` ignore rules could not hide its contents. The unrelated untracked `example/lib/debug_routes.dart` was excluded from that copy and left untouched; the full-directory formatting check reports that existing file, while task-authored/modified files pass.

## Remaining environment and release checks

- Android emulator startup failed before running tests: it required about 7.4 GB of free space and only about 3.6 GB was available at startup. Android integration CI is configured but has not been executed remotely by this session.
- Firefox 155 failed during browser launch with “Could not find profile folder,” including when given a canonical temporary path. This is consistent with the [reported macOS Playwright profile-access issue](https://github.com/microsoft/playwright/issues/42768); no privacy settings were changed. The Linux Firefox CI job remains to be run.
- Playwright WebKit is not the installed Safari application. Safari-specific integration is still unverified.
- A real iOS `simctl openurl` request reached the system confirmation to open the fixture. The available UI tool could not access Simulator, so cold/warm OS link completion is not claimed. Flutter's route-message delivery passed separately in the native integration test.
- Physical Android predictive-back progress/cancellation, physical iOS gestures, associated-domain links, native desktop builds and OS process-death restoration still need platform release validation. The existing widget restoration tests passed.
- Only Flutter 3.47.5 ran locally during this task. The existing 3.27.0/3.32.8/3.41.6/3.47.5 CI matrix must pass on the eventual committed revision. No release tag was created or published.

See [reproduction instructions](platform-validation.md) and [runnable recipes](recipes.md).
