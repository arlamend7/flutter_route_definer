# Pub points and CI compatibility fixes

## Published version versus this checkout

The pub.dev API reported **150/160** points for published `route_definer` **2.0.3** when checked on 2026-09-23 (local date). Its report deducts 10 points for static-analysis findings, including unnecessary imports in the previous implementation. Changing this checkout does not change the score of an already published archive.

The 3.0.0 candidate was analyzed locally with **pana 0.23.19**, Flutter **3.41.6** and Dart **3.11.4**, including documentation generation. It receives **160/160** available points:

| Category | Points |
|---|---|
| Dart file conventions | 30/30 |
| Documentation | 20/20 |
| Platform support analysis | 20/20 |
| Static analysis | 50/50 |
| Dependency compatibility | 40/40 |

This is an observed local result, not a guarantee of the score pub.dev will assign after publication. Its SDK, dependencies, external URL checks and scoring rules can change. Platform points are based on import/dependency analysis; they do not certify native-device behavior. Likes and download counts are independent of pub points.

The package CI job now requires all available points with `pana --exit-code-threshold 0` and uploads the JSON report as `pub-score`. The publication job already depends on all validation jobs. A score check cannot replace SDK tests, browser checks or the required approving review. See [scoring rules](https://pub.dev/help/scoring), [the published score](https://pub.dev/packages/route_definer/score) and [reproduction instructions](../CONTRIBUTING.md#pub-points).

## Causes of the reported CI failures

The logs from [PR #12's initial validation run](https://github.com/arlamend7/flutter_route_definer/actions/runs/35941067574) identify three separate causes:

1. **Flutter 3.27.0 and 3.32.8:** `foundation.dart` does not export `internal`. All three annotations now import it directly from `package:meta/meta.dart`, with an explicit compatible dependency. The SDK floor is unchanged.
2. **Flutter 3.47.5 removal tests:** native `removeRoute` did not call `onDidRemovePage`, leaving the managed stack and push Future unchanged. A private `NavigatorObserver.didRemove` now reconciles managed pages. Both callback paths share an idempotent handler; pageless routes and already-removed entries are ignored. The regression fixture deliberately suppresses the page callback to exercise the observer independently on the installed SDK.
3. **Flutter 3.47.5 browser checks:** the navigation assertions passed, but deleting Chrome's temporary profile raised `ENOTEMPTY`. The harness now waits for graceful shutdown, bounds the wait, and retries asynchronous deletion while subprocesses release files. Navigation assertion failures still fail the job.

The patched SDK matrix must be rerun before release. Other SDKs could not be installed locally: official macOS archive URLs returned 404, and the alternate distribution mirror returned 403. No passing patched GitHub run, native gesture test, merge or publication is claimed here.
