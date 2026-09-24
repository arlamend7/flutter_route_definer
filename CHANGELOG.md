## 3.0.0

- Add resolved `currentRoute`/`stack` inspection snapshots, asynchronous navigation events, optional bounded history and configurable diagnostics with sensitive fields redacted by default. Existing APIs remain available. Report successful managed pops immediately and distinguish them from removal.

- Add instance-owned `RouteDefinerRouter`, `RouterConfig`, typed pages/results, browser history, full URI state, stack serialization and Flutter restoration support.
- Remove the static `AppRouter`, named-route adapter, `GlobalRouteDefiner` and loader wrapper. Configure one `RouteDefinerRouter` directly.
- Unify authorization and redirects under function-based `guards`; remove `isAuthorized`, `beforeEnter` and class-based guard checks. Use one state-aware `title` callback and an optional `appTitle` fallback.
- Require explicit loading, denied, not-found and error builders. Supply opt-in pages through the separate `default_pages.dart` library. Organize source into routing, guards, titles and default_pages folders.
- Add canonical initial stacks and a shared generic `DefinedRouteFactory` for global and per-route native page customization.
- Fail closed on authorization denial and guard errors. Add explicit allow/deny/redirect decisions and exception handling, terminal redirects with loop limits, retry, timeout, cooperative cancellation and access refresh.
- Memoize asynchronous checks across rebuilds and ignore results from removed or covered routes.
- Validate and compile route patterns once. Preserve literal punctuation, Unicode, encoded path segments, repeated query parameters and fragments. Reject ambiguous definitions and prevent near-match shadowing.
- Make route state and definition collections immutable. Add parameter/location helpers.
- Fix stale browser titles, replacement/removal observation and JavaScript/WebAssembly conditional imports.
- Use current Navigator page-removal APIs and typed pop callbacks, respecting `PopScope` through `maybePop`.
- Correct SDK constraints to Flutter >=3.27 / Dart >=3.6 and package:web >=0.4. Add a runnable example, behavioral/browser regressions, SDK/dependency CI, release gates and migration/platform/support documentation.

This is a breaking release. Read MIGRATION.md and doc/compatibility.md; SDK matrix and physical-platform release checks must be green before publication.

# Changelog

## [1.0.0] - Initial release
- Added `AppRouter` setup.
- Route matching and URI param parsing.
- Basic authorization and redirect support.
- Custom guards support via `RouteGuard`.
- Test coverage for core routing logic.

## [1.0.1] - fix documentation and pub score
- Improved documentation comments for public APIs and classes.
- Updated `README.md` with clearer usage examples and removed informal tone.
- Added missing `description`, `homepage`, and `repository` fields to `pubspec.yaml`.
- Ran `dart format .` to ensure consistent code formatting.
- Resolved all issues and warnings reported by `flutter analyze`.
- Ensured `dart pub publish --dry-run` passes without errors or warnings.

## [1.0.2] - Add example
- Add example

## [1.1.0] - 2025-06-18

### Added
- `RouteOptions.merge()` method to allow merging specific route options with global defaults.
- Documentation for `RouteOptions` fields and the `merge()` method for clarity and usability.

### Changed
- Updated GitHub Actions to auto-publish to pub.dev when pushing a version tag (e.g., `v1.2.3`).
- Added basic permission checking in CI workflow to restrict who can push tags (manual check using `github.actor`).

### Fixed
- Improved test coverage and organization of `AppRouter` and guard logic.

## [1.2.0] - 2025-06-18
- Lowered SDK version requirement for better compatibility
- Updated overall project documentation
- Added comprehensive API documentation for the library

## [1.2.2] - 2025-06-18
- Resolved runtime error when redirecting during route build phase by deferring navigation with `Future.microtask`

## [2.0.0] - 2025-08-28
- Stabilized public APIs and bumped package version to 2.0.0.
- Added tests for route guards, title updates, and loader widget to reach full coverage.
- Verified package readiness for publishing with a perfect pub score.

## [2.0.1] - 2025-08-30
- Downgraded `web` dependency and allowed any version for maximum adaptability.

## [2.0.2] - 2025-08-31
- Exported all core classes in `route_definer.dart` for easier package consumption.
- Replaced `dynamic` with `Object?` for `RouteState.arguments` to improve type safety.
- Refined and documented test suite for clearer coverage.

## [2.0.3] - 2025-09-11
- Change the route loader for an stateless widget