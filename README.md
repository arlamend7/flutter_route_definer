# AppRouter

A lightweight, declarative routing package for Flutter, inspired by Angular and Express.js. AppRouter enables flexible navigation with guards, dynamic path matching, argument extraction, and testable logic — all with a minimal footprint.

## Documentation

Official API documentation is available at:

[route_definer library](https://arlamend7.github.io/flutter_route_definer/route_definer/)

## When to Use AppRouter

AppRouter is particularly useful for:

- Applications with complex navigation flows or conditional access
- Modular projects requiring isolated and reusable route definitions
- Projects that benefit from a declarative and testable route structure

Its accompanying test suite ensures:

- Guards work as expected (allow/deny navigation)  
- Path parsing is reliable (path, query, fragment)  
- Dynamic segments are accurately matched and extracted

## Features

AppRouter offers essential features to support complex navigation flows:

- Lightweight and framework-agnostic  
  Designed to be simple, fast, and easy to integrate or test.

- Express-style path and query parsing  
  Easily match and extract segments like `/user/:id/post/:postId`.

- Navigation guards with redirect support  
  Redirect based on conditions such as authentication or user state.

- Route-level configuration and metadata  
  Define route-specific behaviors such as full-screen dialogs and guards.

- Route introspection with `RouteState`  
  Access route path, parameters, query string, fragment, and arguments.

- Fallback and unknown route handling  
  Customize 404 screens or handle unmatched routes programmatically.

## Motivation

Routing systems like Angular and Express.js offer robust navigation features: dynamic segments, guards, redirection, and separation of logic.

AppRouter brings these capabilities natively to Flutter:

- Express-style dynamic path matching  
- Angular-style navigation guards (`canActivate`, `canRedirect`)  
- Separation between route definition and view building  
- Easy-to-mock, test-friendly routing logic


## RouteState Breakdown

The `RouteState` object gives full introspection of the current route:

| Property      | Description                                 |
|---------------|---------------------------------------------|
| `path`        | Raw route path (e.g., `/user/42/post/10`)   |
| `uriParams`   | Extracted parameters (`id`, `postId`, etc.) |
| `queryParams` | Query string values (`?sort=asc`)           |
| `fragment`    | Hash fragment (e.g., `#top`)                |
| `arguments`   | Extra arguments passed via navigation       |


## Migration Guides


## Changelog

See [`CHANGELOG.md`](https://pub.dev/packages/route_definer/changelog) for a full list of updates, features, and breaking changes.

## Roadmap

AppRouter is currently considered stable and production-ready. However, we continue to evaluate new features based on developer feedback and common use cases. Our goal is to make the system more modular and allow additional customization per route when needed. Future decisions and evolutions will be guided by demand and comparisons with other mature routing systems such as Angular Router, .NET routing, and Java frameworks. Improvements will be gradual and driven by practical needs rather than complexity, maintaining the lightweight and intuitive nature of the package.


## Triage & Contributing

AppRouter uses issue priorities similar to Flutter: `P0`, `P1`, `P2`, `P3`.  
To report bugs or suggest features, visit the [GitHub Issues](https://github.com/arlamend7/flutter_route_definer/issues).  
We welcome contributions via pull requests or discussions!
