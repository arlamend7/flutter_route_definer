import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:route_definer_example/native_check.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'native typed pop, veto, Cupertino edge drag and warm route delivery',
      (tester) async {
    final key = GlobalKey<NativeCheckAppState>();
    await tester.pumpWidget(NativeCheckApp(key: key));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select 7'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 7'), findsOneWidget);
    await tester.tap(find.text('Open item'));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(CupertinoPageScaffold));
    await tester.timedDragFrom(Offset(1, size.height / 2),
        Offset(size.width * .85, 0), const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Native routing checks'), findsOneWidget);
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard your draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved'), findsOneWidget);
    // Exercises Flutter's platform message path. Actual OS link dispatch is
    // separately checked with simctl/adb; this is not an associated-domain test.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec()
          .encodeMethodCall(const MethodCall('pushRouteInformation', {
        'location': 'routedefiner://example/item/99?source=native',
        'state': null,
      })),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Select 99'), findsOneWidget);
    expect(key.currentState!.router.currentRoute.state.queryParams['source'],
        'native');
    await tester.pumpWidget(const SizedBox());
  });
}
