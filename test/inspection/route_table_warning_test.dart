import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import '../support/router.dart';

void main() {
  test('diagnostics report complete shadowing without changing precedence', () {
    RouteDefiner<void> page(String path) =>
        RouteDefiner<void>(path: path, builder: (_, __) => const SizedBox());
    final broad = page('/users/:id');
    final specific = page('/users/new');
    final router =
        testRouter([broad, specific, page('/users/'), page('/users/new/edit')]);
    expect(router.routeWarnings, hasLength(1));
    expect(router.routeWarnings.single.route, same(specific));
    expect(router.routeWarnings.single.shadowedBy, same(broad));
    expect(router.routeWarnings.single.toString(),
        contains('Place the more specific'));
    expect(() => router.routeWarnings.clear(), throwsUnsupportedError);
    expect(router.match('/users/new').definition, same(broad));
    router.updateRoutes([specific, broad]);
    expect(router.routeWarnings, isEmpty);
    expect(router.match('/users/new').definition, same(specific));
    router.dispose();
  });

  test('coverage handles dynamic, Unicode, encoded and partial overlaps', () {
    for (final paths in [
      ('/:section/:id', '/users/:name', true),
      ('/users/:id', '/:section/new', false),
      ('/users/:id', '/users/', false),
      ('/users/:id/', '/users/new/', true),
      ('/caf%C3%A9/:id', '/café/new', true),
      ('/files/:id', '/files/a%2Fb', true),
      ('/Users/:id', '/users/new', false),
    ]) {
      expect(RoutePattern(paths.$1).covers(RoutePattern(paths.$2)), paths.$3,
          reason: paths.toString());
    }
  });
}
