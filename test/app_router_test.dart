// test/route_definer_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_definer/route_definer.dart';

class DummyGuard implements RouteGuard {
  final bool allow;
  DummyGuard(this.allow);

  @override
  String? redirect(RouteState state) => allow ? null : '/login';
}

class DummyUserPrefs {
  static bool isAuthenticated = false;
  static dynamic passwordChange;
}

class AuthenticatedRedirectGuard extends RouteGuard {
  @override
  String? redirect(RouteState state) => DummyUserPrefs.isAuthenticated ? '/main' : null;
}

class PasswordChangeProgressGuard extends RouteGuard {
  @override
  String? redirect(RouteState state) {
    final args = state.arguments;
    final emailPresent = args != null && args['email'] != null;
    return (emailPresent || DummyUserPrefs.passwordChange != null) ? null : '/';
  }
}

void main() {
  final mockRoutes = [
    RouteDefiner(path: '/', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/login', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/main', builder: (_, __) => const Placeholder(), requireAuthorization: true),
    RouteDefiner(path: '/article/:id', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/user/:id', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/user/:id/post/:postId', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/settings/:section', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/reset-by-email', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/reset-by-pin', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/search', builder: (_, __) => const Placeholder()),
  ];

  setUpAll(() {
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'Test App',
        isAuthorized: (state) => DummyUserPrefs.isAuthenticated,
        onUnknownRoute: (settings, state) => MaterialPageRoute(builder: (context) => const Placeholder()),
        unauthorizedBuilder: (context, state) => const Placeholder(),
      ),
      mockRoutes,
    );
  });

  group('RouteGuard tests', () {
    test('DummyGuard allows when true', () {
      final guard = DummyGuard(true);
      final state = RouteState(path: '/home', queryParams: {}, fragment: '', arguments: null);
      expect(guard.redirect(state), isNull);
    });

    test('DummyGuard blocks and redirects when false', () {
      final guard = DummyGuard(false);
      final state = RouteState(path: '/home', queryParams: {}, fragment: '', arguments: null);
      expect(guard.redirect(state), '/login');
    });

    group('AuthenticatedRedirectGuard', () {
      test('Redirects to /main when authenticated', () {
        DummyUserPrefs.isAuthenticated = true;
        final guard = AuthenticatedRedirectGuard();
        final state = RouteState(path: '/', queryParams: {}, fragment: '', arguments: null);
        expect(guard.redirect(state), '/main');
      });

      test('Allows access when not authenticated', () {
        DummyUserPrefs.isAuthenticated = false;
        final guard = AuthenticatedRedirectGuard();
        final state = RouteState(path: '/', queryParams: {}, fragment: '', arguments: null);
        expect(guard.redirect(state), isNull);
      });
    });

    group('PasswordChangeProgressGuard', () {
      test('Allows if email argument is present', () {
        final guard = PasswordChangeProgressGuard();
        final state = RouteState(
          path: '/password-change',
          queryParams: {},
          fragment: '',
          arguments: {'email': 'test@example.com'},
        );
        expect(guard.redirect(state), isNull);
      });

      test('Allows if local passwordChange progress exists', () {
        DummyUserPrefs.passwordChange = {'step': 1};
        final guard = PasswordChangeProgressGuard();
        final state = RouteState(path: '/password-change', queryParams: {}, fragment: '', arguments: {});
        expect(guard.redirect(state), isNull);
        DummyUserPrefs.passwordChange = null;
      });

      test('Redirects to / when no progress or email', () {
        DummyUserPrefs.passwordChange = null;
        final guard = PasswordChangeProgressGuard();
        final state = RouteState(path: '/password-change', queryParams: {}, fragment: '', arguments: {});
        expect(guard.redirect(state), '/');
      });
    });
  });

  group('AppRouter static helper methods', () {
    group('isNearMatch', () {
      test('Returns true on near miss with missing param', () {
        expect(AppRouter.isNearMatch('/article/:id', '/article'), isTrue);
        expect(AppRouter.isNearMatch('/user/:id/post/:postId', '/user'), isTrue);
        expect(AppRouter.isNearMatch('/settings/:section', '/settings'), isTrue);
      });

      test('Returns false on clear mismatch', () {
        expect(AppRouter.isNearMatch('/article/:id', '/settings'), isFalse);
        expect(AppRouter.isNearMatch('/user/:id/post/:postId', '/settings'), isFalse);
        expect(AppRouter.isNearMatch('/settings/:section', '/article'), isFalse);
      });

      test('Returns false if full match', () {
        expect(AppRouter.isNearMatch('/article/:id', '/article/123'), isFalse);
      });
    });

    test('extractPathParams extracts params correctly', () {
      final params = AppRouter.extractPathParams('/user/:id', '/user/123');
      expect(params, {'id': '123'});
    });

    test('buildRouteState parses RouteSettings correctly', () {
      const settings = RouteSettings(name: '/page?query=test#frag', arguments: {'some': 'data'});
      final state = AppRouter.buildRouteState(settings);
      expect(state.path, '/page');
      expect(state.queryParams, containsPair('query', 'test'));
      expect(state.fragment, 'frag');
      expect(state.arguments, containsPair('some', 'data'));
    });

    group('matchRoute', () {
      test('Matches correct route with params', () {
        final result = AppRouter.matchRoute('/user/456');
        expect(result.$1, isNotNull);
        expect(result.$1!.path, '/user/:id');
        expect(result.$2, isFalse);
      });

      test('Detects near match when partial', () {
        final result = AppRouter.matchRoute('/user');
        expect(result.$1, isNull);
        expect(result.$2, isTrue);
      });

      test('Returns null and false when no match', () {
        final result = AppRouter.matchRoute('/unknown');
        expect(result.$1, isNull);
        expect(result.$2, isFalse);
      });

      test('Matches route with multiple parameters', () {
        final result = AppRouter.matchRoute('/user/42/post/10');
        expect(result.$1, isNotNull);
        expect(result.$1!.path, '/user/:id/post/:postId');
        expect(result.$2, isFalse);
      });

      test('Prefers exact match over near match', () {
        final result = AppRouter.matchRoute('/search');
        expect(result.$1, isNotNull);
        expect(result.$1!.path, '/search');
        expect(result.$2, isFalse);
      });
    });
  });

  group('AppRouter.analyzeRoute parsing tests', () {
    test('Handles URL without query and fragment', () {
      const settings = RouteSettings(name: '/simplepath', arguments: null);
      final result = AppRouter.analyzeRoute(settings);
      expect(result.state.path, '/simplepath');
      expect(result.state.uriParams, isNull);
      expect(result.state.queryParams, isEmpty);
      expect(result.state.fragment, isEmpty);
      expect(result.state.arguments, isNull);
      expect(result.match, isNull);
      expect(result.isNear, isFalse);
    });

    test('Handles URL with only fragment', () {
      const settings = RouteSettings(name: '/path#section1', arguments: {'foo': 'bar'});
      final result = AppRouter.analyzeRoute(settings);
      expect(result.state.path, '/path');
      expect(result.state.uriParams, isNull);
      expect(result.state.queryParams, isEmpty);
      expect(result.state.fragment, 'section1');
      expect(result.state.arguments, containsPair('foo', 'bar'));
      expect(result.match, isNull);
      expect(result.isNear, isFalse);
    });

    test('Parses multiple query parameters correctly', () {
      const settings = RouteSettings(name: '/search?term=flutter&sort=asc&filter=none');
      final result = AppRouter.analyzeRoute(settings);
      expect(result.state.path, '/search');
      expect(result.state.uriParams, isEmpty);
      expect(result.state.queryParams.length, 3);
      expect(result.state.queryParams['term'], 'flutter');
      expect(result.state.queryParams['sort'], 'asc');
      expect(result.state.queryParams['filter'], 'none');
      expect(result.state.fragment, isEmpty);
      expect(result.match, isNotNull);
      expect(result.isNear, isFalse);
    });

    test('Parses path params, query params, and fragment correctly', () {
      const settings = RouteSettings(name: '/user/42/post/10?sort=desc&highlight=true#section2');
      final result = AppRouter.analyzeRoute(settings);
      final state = result.state;
      final match = result.match;
      final isNear = result.isNear;

      expect(state.path, '/user/42/post/10');
      expect(state.uriParams, isNotNull);
      expect(state.uriParams, containsPair('id', '42'));
      expect(state.uriParams, containsPair('postId', '10'));

      expect(state.queryParams.length, 2);
      expect(state.queryParams['sort'], 'desc');
      expect(state.queryParams['highlight'], 'true');

      expect(state.fragment, 'section2');
      expect(match, isNotNull);
      expect(isNear, isFalse);
    });

    test('Handles /settings/profile with path param and no query/fragment', () {
      const settings = RouteSettings(name: '/settings/profile');
      final result = AppRouter.analyzeRoute(settings);
      expect(result.state.path, '/settings/profile');
      expect(result.state.uriParams, containsPair('section', 'profile'));
      expect(result.state.queryParams, isEmpty);
      expect(result.state.fragment, isEmpty);
      expect(result.match, isNotNull);
      expect(result.isNear, isFalse);
    });

    test('Handles /article/123 with query and fragment', () {
      const settings = RouteSettings(name: '/article/123?ref=newsletter#top');
      final result = AppRouter.analyzeRoute(settings);
      expect(result.state.path, '/article/123');
      expect(result.state.uriParams, containsPair('id', '123'));
      expect(result.state.queryParams, containsPair('ref', 'newsletter'));
      expect(result.state.fragment, 'top');
      expect(result.match, isNotNull);
      expect(result.isNear, isFalse);
    });
  });

  group('AppRouter advanced tests', () {
    test('buildRouteState handles URL without query and fragment', () {
      const settings = RouteSettings(name: '/simplepath', arguments: null);
      final state = AppRouter.buildRouteState(settings);
      expect(state.path, '/simplepath');
      expect(state.uriParams, isNull);
      expect(state.queryParams, isEmpty);
      expect(state.fragment, isEmpty);
      expect(state.arguments, isNull);
    });

    test('buildRouteState handles URL with only fragment', () {
      const settings = RouteSettings(name: '/path#section1', arguments: {'foo': 'bar'});
      final state = AppRouter.buildRouteState(settings);
      expect(state.path, '/path');
      expect(state.uriParams, isNull);
      expect(state.queryParams, isEmpty);
      expect(state.fragment, 'section1');
      expect(state.arguments, containsPair('foo', 'bar'));
    });

    test('buildRouteState parses multiple query parameters correctly', () {
      const settings = RouteSettings(name: '/search?term=flutter&sort=asc&filter=none');
      final state = AppRouter.buildRouteState(settings);
      expect(state.path, '/search');
      expect(state.uriParams, isNull);
      expect(state.queryParams.length, 3);
      expect(state.queryParams['term'], 'flutter');
      expect(state.queryParams['sort'], 'asc');
      expect(state.queryParams['filter'], 'none');
      expect(state.fragment, isEmpty);
    });

    test('buildRouteState parses path params, query params, and fragment correctly', () {
      const settings = RouteSettings(name: '/user/42/post/10?sort=desc&highlight=true#section2');
      final result = AppRouter.analyzeRoute(settings);
      final state = result.state;
      final match = result.match;
      final isNear = result.isNear;

      expect(state.path, '/user/42/post/10');
      expect(state.uriParams, isNotNull);
      expect(state.uriParams, containsPair('id', '42'));
      expect(state.uriParams, containsPair('postId', '10'));

      expect(state.queryParams.length, 2);
      expect(state.queryParams['sort'], 'desc');
      expect(state.queryParams['highlight'], 'true');

      expect(state.fragment, 'section2');
      expect(match, isNotNull);
      expect(isNear, isFalse);
    });

    test('matchRoute returns correct params for complex route', () {
      final result = AppRouter.matchRoute('/user/99/post/12345');
      expect(result.$1, isNotNull);
      expect(result.$1!.path, '/user/:id/post/:postId');
      expect(result.$2, isFalse);

      final params = AppRouter.extractPathParams(result.$1!.path, '/user/99/post/12345');
      expect(params?['id'], '99');
      expect(params?['postId'], '12345');
    });

    test('matchRoute returns null route and false near match for unrelated path', () {
      final result = AppRouter.matchRoute('/completely/unrelated/path');
      expect(result.$1, isNull);
      expect(result.$2, isFalse);
    });

    test('matchRoute near match true when path segments partially match', () {
      final result = AppRouter.matchRoute('/settings');
      expect(result.$1, isNull);
      expect(result.$2, isTrue);
    });

    test('extractPathParams returns empty map if no params in pattern', () {
      final params = AppRouter.extractPathParams('/about', '/about');
      expect(params, isEmpty);
    });

    test('extractPathParams returns empty map if paths do not match', () {
      final params = AppRouter.extractPathParams('/user/:id', '/settings');
      expect(params, isNull);
    });

    test('isNearMatch false if path is longer than pattern', () {
      expect(AppRouter.isNearMatch('/user/:id', '/user/123/extra'), isFalse);
    });

    test('buildRouteState handles empty string path gracefully', () {
      const settings = RouteSettings(name: '', arguments: null);
      final state = AppRouter.buildRouteState(settings);
      expect(state.path, AppRouter.initialRoute);
      expect(state.uriParams, isNull);
      expect(state.queryParams, isEmpty);
      expect(state.fragment, isEmpty);
      expect(state.arguments, isNull);
    });

    test('buildRouteState handles null RouteSettings.name gracefully', () {
      const settings = RouteSettings(name: null, arguments: null);
      final state = AppRouter.buildRouteState(settings);
      expect(state.path, AppRouter.initialRoute);
      expect(state.uriParams, isNull);
      expect(state.queryParams, isEmpty);
      expect(state.fragment, isEmpty);
      expect(state.arguments, isNull);
    });
  });
}
