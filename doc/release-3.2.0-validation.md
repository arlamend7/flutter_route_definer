# 3.2.0 validation record

Local execution: 2026-10-12, macOS, Flutter 3.47.5 / Dart 3.13.4.
This records the working-tree candidate, not a published release or green remote CI.

| Check | Result |
|---|---|
| Static analysis | Passed, no issues |
| Library tests, normal resolution | 86 passed, including 13 new convenience/API regressions |
| Library tests, minimum dependency resolution | 86 passed; dependency resolution restored afterward |
| Example widget tests | 5 passed, including retained tabs, login return and unsaved forms |
| Compile-time typed navigation | Correct inferred result accepted; incompatible result rejected |
| Browser-startup tests | 4 passed |
| Chrome JavaScript | 20 scenarios passed, Chrome 154.0.8037.99 |
| Chrome WebAssembly | 20 scenarios passed, Chrome 154.0.8037.99 |
| Playwright WebKit JavaScript | 20 scenarios passed, WebKit 26.6 |
| iOS integration fixture | Passed on iPhone 17 Pro simulator / iOS 26.4: typed pop, Cupertino edge drag, dirty-form back veto and Flutter warm route-message delivery |
| API documentation | 3 public libraries generated; zero warnings/errors |

The observer-only removal test now unwraps the router's inherited lookup scope;
its behavioral assertions remain intact. All four presets have tests for page
settings, typed results, refresh, restoration and option forwarding. Definition
factory precedence over either default factory and invalid settings are tested.

## Checks still required before publication

- Firefox was attempted, but exited before opening the app with `Could not find
  profile folder`. No navigation assertion ran. Use the Linux CI Firefox job.
- Installed Safari: Playwright WebKit is engine coverage, not an actual Safari run.
- Android native fixture, physical predictive-back completion/cancellation and
  physical iOS system gesture interactions require device/CI execution.
- Actual OS cold/warm links, verified associated domains and OS process-death
  restoration remain unverified. Injected Flutter messages and widget restoration
  do not prove these behaviors.
- The patched SDK matrix (3.27.0, 3.32.8, 3.41.6, 3.47.5 with normal/minimum
  dependencies) needs remote CI execution. Local Flutter 3.27.0 source inspection
  confirmed the preset constructor options, but is not an SDK execution result.
- Final publication dry run and final all-directory formatting verification did
  not execute: automatic approval review reached the account usage limit. The
  implementation/test files were formatted earlier; static analysis passed.

The existing `.github/workflows/validate.yml` contains native/browser jobs and
the SDK matrix. Follow `platform-validation.md` for device/link procedures.
No remote CI run, merge, tag or publication was performed here. The simulator
used for validation was started from Shutdown; cleanup requires tool approval
once the account limit is resolved.

## Pre-commit review

Reviewed public exports, helper/constructor option forwarding, factory precedence,
legacy compatibility, nearest nested lookup, strict query behavior, callback
serialization, examples and all twelve release-plan entries. Corrected stale
public-library/version references in README, migration and compatibility docs.
Relative documentation links, README/minimal-example equality, version/changelog
consistency and `git diff --check` were checked locally. New API, release-doc and
test files are untracked and must be included when staging the commit.
