import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/default_pages.dart' as default_router;

void main() {
  test('location generation round-trips Unicode and encoded slash values', () {
    final pattern = RoutePattern('/files/:name');
    for (final name in [
      'São Paulo',
      'a/b',
      'jane.doe',
      '日本語',
      '%2F',
      'a?b#c'
    ]) {
      final uri = pattern.location(parameters: {
        'name': name
      }, queryParameters: {
        'tag': ['one', 'two']
      }, fragment: 'part 1');
      expect(pattern.match(uri.toString()), {'name': name});
      expect(uri.queryParametersAll['tag'], ['one', 'two']);
      expect(Uri.decodeComponent(uri.fragment), 'part 1');
    }
    expect(RoutePattern('/').location().toString(), '/');
  });

  test('matching has explicit case and trailing slash semantics', () {
    final pattern = RoutePattern('/Docs/:id');
    expect(pattern.match('/Docs/x'), {'id': 'x'});
    expect(pattern.match('/docs/x'), isNull);
    expect(pattern.match('/Docs/x/'), isNull);
    expect(pattern.match('/Docs/'), isNull);
    expect(RoutePattern('/v1.0/(draft)').match('/v1.0/(draft)'), isNotNull);
    expect(RoutePattern('/v1.0').match('/v1X0'), isNull);
  });

  test('invalid patterns, malformed URLs and incorrect parameters fail early',
      () {
    for (final path in [
      'relative',
      '/:id/:id',
      '/:',
      '/:9id',
      '/x?query',
      '/x#f'
    ]) {
      expect(() => RoutePattern(path), throwsArgumentError, reason: path);
    }
    for (final path in ['/x/%', '/x/%GG', '/x/%FF', 'relative']) {
      expect(() => parseRouteUri(path), throwsFormatException, reason: path);
    }
    final pattern = RoutePattern('/x/:id');
    expect(() => pattern.location(), throwsArgumentError);
    expect(() => pattern.location(parameters: {'id': '', 'extra': 'a'}),
        throwsArgumentError);
  });

  test('equivalent parameter patterns are rejected at registration', () {
    RouteDefiner<void> page(String path) =>
        RouteDefiner<void>(path: path, builder: (_, __) => const SizedBox());
    for (final patterns in [
      ['/x/:id', '/x/:name'],
      ['/same', '/same']
    ]) {
      expect(
          () => RouteDefinerRouter(
              loadingBuilder: (_) => const default_router.LoadingPage(),
              deniedBuilder: (_, __) => const default_router.DeniedPage(),
              notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
              errorBuilder: (_, failure, retry) =>
                  default_router.ErrorPage(onRetry: retry),
              routes: patterns.map(page)),
          throwsArgumentError);
    }
    final router = RouteDefinerRouter(
        loadingBuilder: (_) => const default_router.LoadingPage(),
        deniedBuilder: (_, __) => const default_router.DeniedPage(),
        notFoundBuilder: (_, __) => const default_router.NotFoundPage(),
        errorBuilder: (_, failure, retry) =>
            default_router.ErrorPage(onRetry: retry),
        routes: [page('/x/new'), page('/x/:id')]);
    expect(router.match('/x/new').definition!.path, '/x/new');
    expect(router.match('/x/other').definition!.path, '/x/:id');
    router.dispose();
  });

  test('state and definition collections are immutable snapshots', () {
    final params = {'id': '42'};
    final state =
        RouteState(Uri.parse('/x/42?q=a&q=b#part'), uriParams: params);
    params['id'] = '7';
    expect(state.pathInt('id'), 42);
    expect(state.queryParamsAll['q'], ['a', 'b']);
    expect(() => state.uriParams!['id'] = '7', throwsUnsupportedError);
    expect(() => state.queryParamsAll['q']!.clear(), throwsUnsupportedError);
    expect(() => state.queryParams.clear(), throwsUnsupportedError);
    expect(() => state.argumentsAs<int>(), throwsFormatException);
    final guards = <RouteGuard>[];
    final definition = RouteDefiner<void>(
        path: '/', guards: guards, builder: (_, __) => const SizedBox());
    guards.add((_) => const RouteDecision.deny());
    expect(definition.guards, isEmpty);
    expect(() => definition.guards.clear(), throwsUnsupportedError);
  });
}
