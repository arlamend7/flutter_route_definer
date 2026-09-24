import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';

/// Tests for merging behavior of [RouteOptions].
void main() {
  test('merge returns this when other is null', () {
    const RouteOptions opts = RouteOptions(fullscreenDialog: true);
    final RouteOptions merged = opts.merge(null);
    expect(identical(opts, merged), isTrue);
  });

  test('merge combines non-null fields correctly', () {
    const RouteOptions base = RouteOptions(
      maintainState: true,
      fullscreenDialog: false,
      allowSnapshotting: true,
      barrierDismissible: false,
      requestFocus: true,
    );
    const RouteOptions override =
        RouteOptions(fullscreenDialog: true, barrierDismissible: true);
    final RouteOptions merged = base.merge(override);
    expect(merged.fullscreenDialog, isTrue);
    expect(merged.maintainState, isTrue);
    expect(merged.allowSnapshotting, isTrue);
    expect(merged.barrierDismissible, isTrue);
    expect(merged.requestFocus, isTrue);
  });
}
