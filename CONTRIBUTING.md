# Contributing

Report a reproducible navigation failure with the SDK versions, platform, dependency resolution, a small route table, exact navigation sequence, and expected/actual results. Use private reporting for vulnerabilities; see [SECURITY.md](SECURITY.md).

## Local checks

```sh
flutter pub get
flutter analyze
flutter test
(cd example && flutter test)
dart format --output=none --set-exit-if-changed lib test example/lib example/test tool
dart doc --output build/api
dart pub publish --dry-run
```

`tool/browser_check.mjs` requires Node 22+ and Chrome/Chromium. Set `CHROME_BIN` if it is not in the default location. Build and run both backends:

```sh
(cd example && flutter build web --release --no-web-resources-cdn -t lib/browser_check.dart)
node tool/browser_check.mjs example/build/web js
(cd example && flutter build web --release --wasm --no-web-resources-cdn -t lib/browser_check.dart)
node tool/browser_check.mjs example/build/web wasm
```

The harness uses a temporary profile, local server and real browser Back/Forward/reload. It checks actual Wasm execution, title changes, direct entry, serialized arguments, page identity, redirects, typed results, current-route/stack snapshots, event history and log redaction. It does not access your normal browser profile.

Run `flutter pub downgrade` and repeat analysis/tests to check lower dependency bounds; run it separately in `example` for example builds. Restore normal resolution with `flutter pub upgrade` afterward. SDK constraints are promises: do not raise them or add dependencies without checking migration impact. CI covers the minimum, intermediate and current pinned stable SDKs. Update the pinned current version deliberately and retain the minimum check.

## Pub points

The package job runs `pana` 0.23.19 on a copy of the checked-out commit, saves its JSON report as the `pub-score` artifact, and fails if any available pub points are missing (`--exit-code-threshold 0`). Publication depends on this job as well as the SDK and browser checks. Review and update the pinned analyzer when pub.dev changes its scoring tool.

To score a committed revision locally:

```sh
dart pub global activate pana 0.23.19
score_source=$(mktemp -d)
git archive HEAD | tar -x -C "$score_source"
dart pub global run pana --exit-code-threshold 0 "$score_source"
```

This analyzes `HEAD`, excluding uncommitted changes. To check pending edits, make a separate copy of the current source without `.git`, `.dart_tool` or `build`, and pass that directory instead. Use pana's default documentation generator; `--dartdoc-version sdk` does not support all of pana's dartdoc flags on every SDK.

A full local score does not guarantee the published score: pub.dev analyzes the uploaded version with its own current SDK, dependencies and scoring rules. Likes and download counts are separate metrics. See [pub.dev scoring](https://pub.dev/help/scoring) and [the recorded score and CI findings](doc/pub-score.md).

Add a behavioral regression test for a routing defect. Exercise visible screens, stack/URI state and returned values. Do not merely assert that an internal method was called. Require all four page builders in examples; opt in to the separate default-pages import only where intended. Preserve Page settings in custom route factories. Keep generated/build files out of git.

## Release checklist

- [ ] All validation jobs pass on the exact release commit, including downgraded dependencies and JS/Wasm browser behavior.
- [ ] The `pub-score` artifact awards every available point, with documentation checks enabled.
- [ ] Review compatibility claims, migration instructions and the complete publication dry-run file list.
- [ ] Run Android predictive-back and iOS swipe-back tests on real devices or supported emulators; verify PopScope veto, typed pop and interruption of pending guards.
- [ ] Smoke-test supported desktop application setup and native deep links; record OS/SDK/device versions.
- [ ] Review performance and incremental build-size measurements for material regressions.
- [ ] Update CHANGELOG, version and release-validation evidence; remove “unreleased” when publishing.
- [ ] Ensure pub.dev OIDC repository/tag settings and GitHub tag protections are configured by a maintainer.

Pushing a version tag triggers publication only after the reusable validation workflow succeeds. The tag must equal `v` plus the pubspec version, and its changelog entry must no longer be marked unreleased. The workflow uses the Dart team's OIDC publisher; no long-lived publishing secret belongs in the repository. Do not push a release tag while validation remains provisional.

API removals, incompatible matching behavior and supported-SDK floor increases require a major version under this project's policy. Prefer a documented deprecation cycle for ordinary API renames. Authorization bypass fixes must not preserve insecure behavior for compatibility. No response-time or multi-year support guarantee is implied for this community-maintained package.
