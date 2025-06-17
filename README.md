# AppRouter for Flutter

**AppRouter** is a flexible and scalable routing system for Flutter, inspired by Angular and Express.js. It supports route parameters, guards, redirects, and authentication control, making it suitable for complex and modular Flutter applications.

## Overview

AppRouter is particularly useful for:

- Applications with complex navigation flows or conditional access
- Modular projects requiring isolated and reusable route definitions
- Maintaining a declarative and testable route structure

Its accompanying test suite ensures:

- Navigation guards work as expected, blocking or allowing access
- Path parsing is reliable across path, query, and fragment variants
- Dynamic path segments are accurately extracted and matched

---

## Motivation

Routing systems in frameworks such as Angular and Express.js provide robust support for dynamic paths (`/user/:id`, `/post/:postId`), redirection, authentication, and guard logic. AppRouter brings these capabilities to Flutter with:

- Express-style dynamic path matching
- Angular-style navigation guards (`canActivate`, `canRedirect`)
- Clear separation between route definitions and views
- Easy-to-mock, testable routing logic

---

## Getting Started

### Example Setup

```dart
class AuthenticatedRedirectGuard extends RouteGuard {
  @override
  String? redirect(RouteState state) {
    return AuthenticationService().isAuthenticated ? null : '/main';
  }
}

class PasswordChangeProgressGuard extends RouteGuard {
  @override
  String? redirect(RouteState state) {
    return state.arguments?["email"] != null ? null : '/login';
  }
}

void main() {
  final mockRoutes = [
    RouteDefiner(
      path: "/login",
      builder: (context, state) => LoginView(
        model: LoginViewModel(
          context: context,
          email: state.arguments?.email as String?,
          password: state.arguments?.password as String?,
          redirectUrl: state.queryParams['redirectUrl'],
        ),
      ),
      guards: [AuthenticatedRedirectGuard()],
    ),
    RouteDefiner(path: '/main', builder: (_, __) => const Placeholder(), requireAuthorization: true),
    RouteDefiner(path: '/article/:id', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/user/:id', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/user/:id/post/:postId', builder: (_, __) => const Placeholder()),
    RouteDefiner(path: '/settings/:section', builder: (_, __) => const Placeholder()),
    RouteDefiner(
      path: '/reset-password',
      builder: (_, state) => PasswordChangeView(email: state.arguments!["email"]),
      guards: [PasswordChangeProgressGuard()],
    ),
    RouteDefiner(path: '/search', builder: (_, __) => const Placeholder()),
  ];

  setUpAll(() {
    AppRouter.init(
      GlobalRouteDefiner(
        initialRoute: '/',
        title: 'Test App',
        isAuthorized: (state) => DummyUserPrefs.isAuthenticated,
        onUnknownRoute: (settings, state) => MaterialPageRoute(builder: (_) => const Placeholder()),
        unauthorizedBuilder: (_, __) => const Placeholder(),
      ),
      mockRoutes,
    );
  });

  runApp(MyApp());
}
```

In your `MaterialApp` configuration:

```dart
MaterialApp(
  title: AppRouter.title,
  initialRoute: AppRouter.initialRoute,
  onGenerateRoute: AppRouter.onGenerateRoute,
  onUnknownRoute: AppRouter.onUnknownRoute,
)
```

---

## 1. RouteGuard Testing

### Example: DummyGuard

```dart
class DummyGuard implements RouteGuard {
  final bool allow;
  DummyGuard(this.allow);

  @override
  String? redirect(RouteState state) => allow ? null : '/login';
}
```

This guard simulates simple authorization behavior:

- If `allow` is `true`, navigation is permitted.
- If `false`, the user is redirected to `/login`.

### Tested Scenarios

- Navigation allowed based on condition
- Navigation blocked and redirected appropriately

---

## 2. RouteState Breakdown

The `RouteState` class provides detailed information about the current route:

- `path`: Raw route path (e.g., `/user/42/post/10`)
- `uriParams`: Extracted path parameters (e.g., `id`, `postId`)
- `queryParams`: Parsed query string (e.g., `?sort=asc`)
- `fragment`: Hash fragment (e.g., `#top`)
- `arguments`: Additional navigation arguments
- `match`: Whether the route matched exactly
- `isNear`: Whether the route was a near match

Example URLs tested include:

- Path-only routes
- Routes with query strings
- Routes with fragments
- Combined formats such as `/user/42/post/10?sort=desc#top`

---

## 3. Route Matching API

### AppRouter Interface

```dart
class AppRouter {
  static void init(GlobalRouteDefiner definer, List<RouteDefiner> routes);
  static Route<dynamic>? onGenerateRoute(RouteSettings settings);
  static Route<dynamic>? onUnknownRoute(RouteSettings settings);
  static String get initialRoute;
  static String get title;
  static (RouteDefiner?, bool) matchRoute(String path);
  static Map<String, String>? extractPathParams(String pattern, String path);
  static bool isNearMatch(String pattern, String path);
  static ({RouteState state, RouteDefiner? match, bool isNear}) analyzeRoute(RouteSettings settings);
  static RouteState buildRouteState(RouteSettings settings);
}
```

### Function Descriptions

- `init(...)`: Initializes the router with global configuration and route definitions.
- `onGenerateRoute(...)`: Builds the appropriate route based on path matching.
- `onUnknownRoute(...)`: Called when no route is found.
- `initialRoute`, `title`: Provide access to globally defined values.
- `matchRoute(...)`: Attempts to find a matching route for a given path.
- `extractPathParams(...)`: Parses dynamic segments from a path (e.g., `:id`).
- `isNearMatch(...)`: Indicates if the path is almost matching a route, useful for fallback logic.
- `analyzeRoute(...)`: Provides a comprehensive analysis of a route from settings.
- `buildRouteState(...)`: Constructs a full `RouteState` object from `RouteSettings`.

---

## Conclusion

AppRouter draws from the best practices of Angular and Express.js but is built natively for Flutter. It provides robust, declarative routing suitable for applications that require authentication, path guards, and modular route handling. With built-in testability and separation of concerns, it’s ideal for both small and large-scale Flutter projects.