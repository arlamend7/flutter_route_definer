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
