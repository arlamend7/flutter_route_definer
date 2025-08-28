import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';

void main() {
  test('merge returns this when other is null', () {
    const opts = RouteOptions(fullscreenDialog: true);
    final merged = opts.merge(null);
    expect(identical(opts, merged), isTrue);
  });
}
