import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:route_definer/default_pages.dart' as default_router;
import 'package:route_definer/route_definer.dart';
import 'package:route_definer_example/widgets/navigation_inspector.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final signedIn = ValueNotifier(false);
  late final RouteDefinerRouter router;
  late final RouteDefiner<int> item;
  var simulateFailure = true;

  @override
  void initState() {
    super.initState();
    item = RouteDefiner<int>(
      path: '/items/:id',
      data: {'section': 'catalog'},
      title: (state) => 'Item ${state.requirePathParameter('id')}',
      builder: (context, state) => screen('Item ${state.pathInt('id')}', [
        Text('Query tags: ${state.queryParamsAll['tag'] ?? []}'),
        Text('Fragment: ${state.fragment}'),
        FilledButton(
            onPressed: () => router.pop<int>(state.pathInt('id')),
            child: const Text('Choose this item')),
      ]),
    );
    router = RouteDefinerRouter(
      // These are independent opt-ins. The library defaults to neither.
      historyLimit: 50,
      diagnostics: kDebugMode
          ? NavigationDiagnostics(
              logger: (message) => debugPrint('[navigation] $message'),
              // URI values, arguments, metadata and error details stay redacted.
            )
          : null,
      refreshListenable: signedIn,
      restorationScopeId: 'navigation',
      appTitle: 'Route Definer',
      resolutionTimeout: const Duration(seconds: 15),
      loadingBuilder: (_) => screen('Checking access', [
        const CircularProgressIndicator(),
      ]),
      deniedBuilder: (_, __) => screen('Access denied', [
        const Text('This account cannot view this page.'),
      ]),
      // All page builders are explicit. Opt in to the provided error page here.
      errorBuilder: (_, failure, retry) => Scaffold(
        appBar: appBar('Navigation failed'),
        body: default_router.ErrorPage(
          onRetry: retry,
          message: 'The demonstration service is unavailable. Try again.',
        ),
      ),
      notFoundBuilder: (_, state) =>
          screen('Page not found', [Text(state.uri.toString())]),
      routes: [
        RouteDefiner<void>(
            path: '/',
            title: (_) => 'Home',
            builder: (context, _) => screen('Route Definer', [
                  const Text(
                      'Try browser Back, Forward and refresh after opening an item.'),
                  FilledButton(
                      onPressed: () async {
                        final location = item.location(parameters: {
                          'id': '42'
                        }, queryParameters: {
                          'tag': ['flutter', 'routing']
                        }, fragment: 'details');
                        final selected =
                            await router.push<int>(location.toString());
                        if (!context.mounted || selected == null) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Selected item $selected')));
                      },
                      child: const Text('Open item and return a typed result')),
                  OutlinedButton(
                      onPressed: () => router.go('/account'),
                      child: const Text('Open guarded account')),
                  OutlinedButton(
                      onPressed: () => router.go('/denied'),
                      child: const Text('Denied authorization')),
                  OutlinedButton(
                      onPressed: () => router.go('/retry'),
                      child: const Text('Recover from a guard error')),
                  OutlinedButton(
                      onPressed: () => router.go('/missing'),
                      child: const Text('Unknown route')),
                ])),
        item,
        RouteDefiner<void>(
            path: '/account',
            title: (_) => 'Account',
            guards: [
              (current) => signedIn.value
                  ? const RouteDecision.allow()
                  : RouteDecision.redirect(Uri(
                      path: '/login',
                      queryParameters: {
                          'next': current.state.uri.toString()
                        }).toString())
            ],
            builder: (_, __) => screen('Account', [
                  const Text(
                      'You are signed in. Signing out refreshes access checks.'),
                  FilledButton(
                      onPressed: () => signedIn.value = false,
                      child: const Text('Sign out and recheck access')),
                ])),
        RouteDefiner<void>(
            path: '/login',
            title: (_) => 'Sign in',
            builder: (_, state) => screen('Sign in', [
                  const Text(
                      'This local demo has no server or real credentials.'),
                  FilledButton(
                      onPressed: () {
                        signedIn.value = true;
                        // Only an application-approved destination is accepted.
                        router.replace(state.queryParams['next'] == '/account'
                            ? '/account'
                            : '/');
                      },
                      child: const Text('Sign in')),
                ])),
        RouteDefiner<void>(
            path: '/denied',
            guards: [(_) => const RouteDecision.deny()],
            builder: (_, __) => const Text('This must never be built')),
        RouteDefiner<void>(
            path: '/retry',
            guards: [
              (_) {
                if (simulateFailure) {
                  simulateFailure = false;
                  throw StateError('Simulated service failure');
                }
                return const RouteDecision.allow();
              }
            ],
            builder: (_, __) =>
                screen('Recovered', [const Text('Retry succeeded.')])),
      ],
    );
  }

  AppBar appBar(String title) => AppBar(title: Text(title), actions: [
        IconButton(
            tooltip: 'Inspect navigation',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showModalBottomSheet<void>(
                  context: router.navigatorKey.currentContext!,
                  builder: (_) => NavigationInspector(router: router),
                )),
        IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => router.go('/')),
      ]);

  Widget screen(String title, List<Widget> children) => Scaffold(
        appBar: appBar(title),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    for (final child in children)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: child)
                  ],
                ))),
      );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: router.appTitle,
        routerConfig: router.config,
        restorationScopeId: 'example',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      );

  @override
  void dispose() {
    router.dispose();
    signedIn.dispose();
    super.dispose();
  }
}
