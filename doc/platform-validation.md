# Native and additional browser validation

See [3.2.0 results and outstanding release gates](release-3.2.0-validation.md).

## Native fixture

`python3 tool/prepare_native_fixture.py` creates disposable Android/iOS runners in `build/native_fixture`. Pass `--flutter /absolute/path/to/flutter` if necessary. It configures a test-only `routedefiner://example` URL scheme. Native boilerplate is regenerated with the selected SDK; the source and integration tests remain in `example/lib/native_check.dart` and `example/integration_test/navigation_test.dart`.

Run on an available simulator/emulator:

```sh
cd build/native_fixture
flutter test integration_test/navigation_test.dart -d DEVICE_ID
```

The test checks inferred typed results, an actual Cupertino widget edge-drag on a native runtime, dirty-form back veto and Flutter's platform route-message delivery. It does not simulate Android predictive-back progress or prove OS domain association. The regular library suite separately checks stack restoration with `restartAndRestore`; do not interpret that as an OS process-death test.

For OS link dispatch, build/install the normal fixture (`flutter run -d DEVICE_ID`) and open these links while running and after terminating the fixture:

```sh
xcrun simctl openurl booted 'routedefiner://example/item/99?source=warm'
adb shell am start -W -a android.intent.action.VIEW -d 'routedefiner://example/item/99?source=warm'
```

Check that **Select 99** appears. Repeat with a different ID after terminating the app, then verify Back. Use only this generated fixture's bundle/package ID for termination. Universal/app links require your own verified domain and association files; this custom-scheme fixture cannot validate those.

The validation workflow runs the native integration suite on iOS and Android emulators. Physical predictive-back completion/cancellation, iOS system interactions, associated domains and process-death restoration remain separate release checks.

## Firefox and WebKit

The Playwright harness reuses every navigation assertion from the Chrome harness, including Back/Forward/reload, title, arguments, identity, typed results, redirects, event history and log redaction.

```sh
npm ci --prefix tool/browsers
npx --prefix tool/browsers playwright install firefox webkit
(cd example && flutter build web --release --no-web-resources-cdn -t lib/browser_check.dart)
node tool/browsers/check.mjs example/build/web firefox js
node tool/browsers/check.mjs example/build/web webkit js
```

On Linux CI use `playwright install --with-deps`. Playwright WebKit is useful engine coverage, but it is not a test of the installed Safari application. Chrome still separately verifies the Wasm backend. Pin browser tooling using the committed npm lockfile; it adds no runtime dependency to the Flutter package.
