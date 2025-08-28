# Migrating from 1.2.2 to 2.0.0

Version 2.0.0 introduces several breaking changes and new capabilities. This guide describes how to update an application built on 1.2.2 to the new APIs.

## Guard API

- `RouteGuard.redirect(RouteState)` has been replaced with the asynchronous `RouteGuard.check(CurrentRoute)`.
- Guards no longer return a redirect path. Perform navigation inside `check` using the provided `BuildContext`.
- A new `CurrentRoute` object exposes `context`, `route`, and `state` for guards and loaders.

**Before**
```dart
class AuthGuard extends RouteGuard {
  @override
  String? redirect(RouteState state) => isLoggedIn ? null : '/login';
}
```

**After**
```dart
class AuthGuard extends RouteGuard {
  @override
  Future<void> check(CurrentRoute current) async {
    if (!isLoggedIn) {
      Navigator.pushReplacementNamed(current.context, '/login');
    }
  }
}
```

## Route definitions

- `requireAuthorization` and the global `isAuthorized` callback were removed.
- Each `RouteDefiner` may now supply an asynchronous `isAuthorized` function.
- The `evaluateRedirect` method was removed; guards are run automatically.
- Optional `data` and lazy `title` properties were added.

**Before**
```dart
RouteDefiner(
  path: '/profile',
  builder: (ctx, state) => const ProfilePage(),
  requireAuthorization: true,
  guards: [AuthGuard()],
);
```

**After**
```dart
RouteDefiner(
  path: '/profile',
  builder: (ctx, state) => const ProfilePage(),
  isAuthorized: (current) async => isLoggedIn,
  guards: [AuthGuard()],
  title: () async => 'Profile',
);
```

## Global configuration

- `GlobalRouteDefiner.isAuthorized` and `onRedirect` were removed.
- `unauthorizedBuilder` now receives `(BuildContext, CurrentRoute)`.
- New optional `loaderBuilder` lets you show a widget while guards or authorization run.

**Before**
```dart
GlobalRouteDefiner(
  initialRoute: '/',
  title: 'App',
  isAuthorized: (state) => isLoggedIn,
  onRedirect: (state, target, task) => const CircularProgressIndicator(),
  unauthorizedBuilder: (ctx, state) => const Text('Denied'),
  onUnknownRoute: ...,
);
```

**After**
```dart
GlobalRouteDefiner(
  initialRoute: '/',
  title: 'App',
  loaderBuilder: (current) => const CircularProgressIndicator(),
  unauthorizedBuilder: (ctx, current) => const Text('Denied'),
  onUnknownRoute: ...,
);
```

## Title updates

`RouteDefiner` can now expose a lazy `title` used by the new `TitleObserver` to update the browser or app bar title:

```dart
MaterialApp(
  navigatorObservers: [TitleObserver(appTitle: TitleObserver.defaultTitleGenerator)],
);
```

## Summary

After updating guards, route definitions, and global configuration as shown above, the application will be compatible with version 2.0.0.
