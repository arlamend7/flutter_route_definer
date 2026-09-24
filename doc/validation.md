# 3.0.0 implementation validation

Date: 2026-09-23. Local SDK: Flutter **3.41.6**, Dart **3.11.4**. Host: macOS arm64, Apple M5, 16 GB RAM. The changes are prepared for review; this task does not publish a release.

## Checks performed

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool` | Clean |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub` | 57 unit/widget tests pass with normal resolution |
| `flutter pub downgrade`, then `flutter test --no-pub` | 57 tests pass with the minimum resolution, including web 0.4.0 |
| `cd example && flutter test --no-pub` | Example sign-in, typed result, inspector dialog and retry scenario passes |
| Example `flutter build web --release` | Compiles |
| Example `flutter build web --release --wasm` | Compiles separately |
| Browser fixture + `node tool/browser_check.mjs … js` | Actual Chrome JS assertions pass |
| Browser fixture + `node tool/browser_check.mjs … wasm` | Actual Chrome Wasm assertions pass; harness verifies Wasm was selected |
| Minimum web 0.4.0 JS/Wasm fixture builds and browser checks | Both pass |
| `dart doc --output build/api-inspection` | 0 warnings, 0 errors |
| `dart pub publish --dry-run` from isolated source copy | 0 warnings; no publication |
| Workflow/issue YAML syntax | Parsed successfully with Ruby Psych |
| Local Markdown links | All file targets resolve |
| `tool/check_release.py` | Rejects wrong version tags and an unreleased changelog |
| README Dart examples | All 19 snippets type-check; the 32-line minimal quick start compiles in a release web build |
| Matching benchmark | Actual registry measured at 10/100/1,000 routes; see performance report |
| JavaScript size comparison | Plain Navigator baseline and Router fixtures built with identical flags |

Normal runtime dependency resolution uses web 1.1.1; the downgraded run uses web 0.4.0. Normal resolution is restored afterward. Browser tests use Node and a fresh temporary headless Chrome 151.0.7922.109 profile, a local HTTP server, and no personal browser data. Each browser run passes 16 grouped checks, including current-route inspection, stack snapshots, event history and diagnostic redaction. The full runnable example compiled and the tested flows did not report runtime errors.

The working-tree publication dry run warns about uncommitted changes, as expected. An isolated copy of the source was used to distinguish that warning from actual package validation problems. Generated builds/caches, workflow configuration, lock files and root screenshots are excluded from publication. Review the dry-run file list again on the release commit.

The 43 existing regressions passed before inspection changes. The current suite has 57 tests: 14 additional inspection/history/diagnostic tests retain the original coverage and verify the new contracts. Source and tests are grouped by routing, guards, inspection, titles and default pages. The 19 README Dart blocks were extracted, wrapped only where their documented placement requires it, and checked against the current API; temporary analysis files were removed afterward. The quick start matches `example/lib/minimal.dart` exactly, which also compiles as a release web application. Typed results and authentication remain in the dedicated guide sections and full example. The permanent example test also checks its inspector panel.

## Important regressions covered

- Current-route metadata and stack snapshots expose independent read-only collection values; history retains bounded events after pages leave the stack.
- Pop events are immediate and not duplicated by framework cleanup; removal below the top preserves the active route and identifies the removed subject.
- Event streams are asynchronous, independent of history retention and closed on disposal. Dialogs and independent child routers stay outside each other's managed stacks.
- Guard outcomes, redirect loops, timeout failures and late cancellations are observed without false success events. Default logging redacts dynamic values; custom logging failures cannot change navigation outcomes. Disabled capture does not traverse metadata.
- Required application-selected loading, denied, not-found and error builders are exercised. Guard denial and exceptions cannot build protected content.
- Redirects stop later guards and page construction; loops become failures; timeout/retry are explicit.
- Rebuilds do not repeat checks; pending covered/removed routes cancel and ignore late completions.
- Complete matches win over earlier near matches; literals, encoded slashes, Unicode and repeated queries behave consistently.
- Typed Router results, pop veto, dialogs, page removal, replacement and stack reset behave predictably.
- Browser Back/Forward/reload and cold direct entry restore URL-addressable pages; typed results and title updates work in JS and Wasm.
- Reused pages read updated definitions and restored arguments. Argument-dependent checks rerun without losing page identity or an outstanding result Future.
- Flutter restoration and JSON argument round-trips work. Corrupt history falls back to its visible URI; malformed incoming paths produce controlled errors.
- Nested Router back dispatch affects only the active child; independent instances do not share route registries.
- Stale title successes/failures, removal/replacement below the top, dialogs, explicit observer disposal and Navigator detachment cannot overwrite a newer title.

## Remaining release gates

The minimum SDK (3.27.0), intermediate 3.32.8 and current stable 3.47.5 were not executable locally: official SDK archive/manifest requests returned HTTP 404. Required APIs were verified in Flutter 3.27.0's official source, but this does not establish compilation. The added exact-version CI matrix must pass before release.

Physical Android predictive-back, iOS swipe-back/universal links, native desktop builds, standalone material_ui/cupertino_ui integration, Firefox/Safari, assistive technology, retained heap and device AOT frame measurements remain unverified. See [compatibility](compatibility.md), [performance](performance.md) and [the release checklist](../CONTRIBUTING.md). No successful GitHub CI run is claimed by this local session.
