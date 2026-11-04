# Release 4.0.0: opt-in title publishing

Status: versioned source candidate; not yet published to pub.dev.

## Breaking change

`RouteDefinerRouter` and `createMaterialRouter` now accept an optional
`onTitleChanged` callback. Without it, route title resolvers do not run and the
router does not publish titles. The core package no longer imports or depends
on `web`. This behavior change requires a major version under the project's
release policy.

To retain browser titles, add `web` to the application's dependencies and pass
`onTitleChanged: (title) => web.document.title = title`, importing
`package:web/web.dart` as `web` in a web-only entry point. For cross-platform
applications, keep the browser import behind an application-owned conditional
import. See the [migration guide](../MIGRATION.md#adopting-400-from-320).

When enabled, asynchronous title handling, `appTitle` fallback, dialog behavior,
and restored-argument refresh are retained. All 3.2.0 convenience APIs remain
available. SDK constraints remain Flutter >=3.27.0 and Dart >=3.6.0 <4.0.0.

## Validation

Local execution: 2026-11-03, macOS, Flutter 3.47.5 / Dart 3.13.4.
The implementation checks below ran on commit `73db72d`, before this version
and documentation update.

| Check | Result |
|---|---|
| Static analysis | Passed, no issues |
| All-directory Dart formatting | Passed, no changes required |
| Library tests | 90 passed, including opt-in/default-disabled title publishing for both constructors |
| Example tests | 5 passed |
| Chrome JavaScript | 20 navigation scenarios passed, including titles and restored titles |
| Chrome WebAssembly | 20 navigation scenarios passed with actual Wasm execution |
| Core dependency resolution | `flutter pub get --offline` removed `web`; the browser example retains its own dependency |

Additional checks on the 4.0.0 source candidate:

- `RELEASE_TAG=v4.0.0 python3 tool/check_release.py` verified the version and changelog.
- API documentation generated all 3 public libraries with zero warnings or errors.
- The publication dry run validated the archive contents; generated files and
  lockfiles are excluded. Its initial warning concerned uncommitted release
  metadata, requiring a repeat from the committed tree before pushing.

## Remaining publication gates

The remote SDK/dependency matrix and native/browser jobs must pass on the final
release commit. Broader device, Safari and OS-link coverage limitations from the
[3.2.0 validation record](release-3.2.0-validation.md#checks-still-required-before-publication)
remain applicable; the local Chrome checks above do not replace them.
Pushing the source does not publish a package. A separate `v4.0.0` tag triggers
the validation and publication workflow after release gates are satisfied.
