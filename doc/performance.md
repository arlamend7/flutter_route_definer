# Performance and scope

History and diagnostics are disabled by default. Enabled history keeps a bounded number of events, each with stack snapshots; payload size and stack depth still affect memory. Disabled capture skips timestamps, snapshot traversal and formatting (covered by a regression).

The matcher precompiles validated segment patterns once and parses an incoming URI once per lookup. Matching remains linear in the number of definitions, preserving declaration-order precedence. There is no code generator, trie, route cache or routing-engine dependency beyond Flutter. `web` supplies browser integration and `meta` supplies annotations.

## Executed matching benchmark

Run `flutter test tool/benchmark_test.dart --reporter expanded`. Recorded on 2026-09-23 using Flutter 3.41.6 / Dart 3.11.4, macOS arm64, Apple M5 (10 CPU cores, 16 GB RAM). This is a host VM/JIT benchmark using the actual `RouteDefinerRouter.match`, including URI parsing and immutable state construction. Partial paths are ordinary misses; there is no separate near-match API. It is not an AOT mobile or browser frame benchmark.

Tables contain alternating static and dynamic definitions. Each case warms up 2,000 times, then measures 31 batches of 100 lookups. Reported medians and p95 are of batch averages in microseconds per lookup; they are not individual-request tail latencies. JIT startup, thermal state and host scheduling affect these small timings. Raw data is in [benchmark-results.json](benchmark-results.json).

| Routes | Case | Median µs | p95 batch-average µs |
|---|---|---:|---:|
| 10 | first | 1.85 | 3.12 |
| 10 | last | 0.70 | 1.81 |
| 10 | miss | 0.36 | 0.67 |
| 10 | partial | 0.36 | 0.55 |
| 100 | first | 0.34 | 0.59 |
| 100 | last | 1.19 | 1.78 |
| 100 | miss | 0.51 | 0.77 |
| 100 | partial | 0.87 | 1.28 |
| 1000 | first | 0.32 | 0.97 |
| 1000 | last | 8.49 | 8.95 |
| 1000 | miss | 3.18 | 3.43 |
| 1000 | partial | 6.85 | 7.31 |

Single construction observations, including validation and the initial registry scan, were 4,133 µs (10 definitions, first/JIT-cold), 507 µs (100), and 3,766 µs (1,000). These are not statistically stable initialization estimates. Do not infer that the smaller table intrinsically initializes more slowly.

These measurements justify retaining the simple linear matcher. A provisional investigation threshold is 100 µs p95 batch average for a 1,000-route miss/last-match workload on this machine, and no unexplained >2× regression against repeated runs of the same revision/settings. This is a diagnostic budget, not a portable timing assertion in CI.

## Behavioral overhead and measurement limits

Regression tests require one guard attempt across unrelated rebuilds, zero protected builder calls after rejection/redirect, no later guard calls after cancellation, and listener cleanup on disposal. Browser tests check real JS and Wasm execution separately. The normal example remains small enough to understand and runs without service dependencies.

Still needed before claiming a universal performance budget: device AOT navigation/frame profiles, retained-heap analysis after repeated stack churn, browser heap growth, and equivalent native/Wasm release size measurements for version 3. The pre-implementation audit measurements describe 2.x and must not be reused as 3.0 results. Network requests and screen rendering must be measured separately from routing overhead. No guarantee of zero retained application Futures is possible without cooperative cancellation.

Follow [Flutter profiling guidance](https://docs.flutter.dev/perf/ui-performance) in profile mode on representative devices and [application-size guidance](https://docs.flutter.dev/perf/app-size) with identical compiler/renderer/asset settings. Record compiler version, device, warm-up, sample count, variance, compressed transfer size and uncompressed code separately. Investigate an incremental compressed code increase above 25 KB for equivalent small applications, rather than silently treating a richer demo as an equivalent baseline.

## Executed JavaScript size comparison

Flutter 3.41.6 / Dart 3.11.4, package:web 1.1.1, `flutter build web --release --no-pub --no-web-resources-cdn`. Both fixtures display two Material screens with a navigation button. Run from `example` with `-t ../tool/size_baseline.dart --output build/size_baseline` and `-t ../tool/size_router.dart --output build/size_router`. The baseline uses plain imperative Navigator navigation; the library fixture uses Router and explicitly selects the optional status pages. Raw measurements are in [size-results.json](size-results.json).

| Application | main.dart.js bytes | gzip level 9 bytes | Incremental gzip bytes |
|---|---:|---:|---:|
| Plain Navigator baseline | 1,752,880 | 514,471 | — |
| route_definer Router | 1,797,253 | 529,105 | 14,634 |

Gzip uses a fixed timestamp and level 9. These numbers compare generated application JavaScript, excluding source maps, common renderer binaries and assets. They are not total download or installation sizes. The library fixture includes Flutter Router/history/restoration and the opted-in pages, so this comparison does not isolate library code alone. It does not exercise every optional feature. Native, Wasm and retained-heap size measurements remain unexecuted.
