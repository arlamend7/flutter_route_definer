import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/default_pages.dart' as pages;

void main() => runApp(const RecipesApp());

/// Complete recipes for login return locations, retained tabs and dirty forms.
class RecipesApp extends StatefulWidget {
  const RecipesApp({super.key});
  @override
  State<RecipesApp> createState() => RecipesAppState();
}

class RecipesAppState extends State<RecipesApp> {
  final signedIn = ValueNotifier(false);
  late final RouteDefinerRouter router;

  @override
  void initState() {
    super.initState();
    router = recipeRouter([
      RouteDefiner<void>(
          path: '/',
          builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('Routing recipes')),
                body: Column(children: [
                  TextButton(
                      onPressed: () =>
                          router.push<void>('/account?section=orders#recent'),
                      child: const Text('Protected account')),
                  TextButton(
                      onPressed: () => router.push<void>('/tabs'),
                      child: const Text('Retained tabs')),
                  TextButton(
                      onPressed: () => router.push<void>('/editor'),
                      child: const Text('Unsaved form')),
                ]),
              )),
      RouteDefiner<void>(
          path: '/account',
          guards: [
            (current) => signedIn.value
                ? const RouteDecision.allow()
                : RouteDecision.redirect(Uri(path: '/login', queryParameters: {
                    'returnTo': current.state.uri.toString(),
                  }).toString()),
          ],
          builder: (_, state) => Scaffold(
                appBar: AppBar(title: const Text('Account')),
                body: Column(children: [
                  Text('Destination: ${state.uri}'),
                  TextButton(
                      onPressed: () => signedIn.value = false,
                      child: const Text('Sign out')),
                ]),
              )),
      RouteDefiner<void>(
          path: '/login',
          builder: (_, state) => Scaffold(
                appBar: AppBar(title: const Text('Sign in')),
                body: TextButton(
                    onPressed: () {
                      final destination =
                          safeReturnLocation(state.queryParams['returnTo']);
                      signedIn.value = true;
                      router.replace(destination);
                    },
                    child: const Text('Sign in and continue')),
              )),
      RouteDefiner<void>(
          path: '/tabs', builder: (_, __) => RetainedTabs(parent: router)),
      RouteDefiner<void>(
          path: '/editor', builder: (_, __) => DraftEditor(router: router)),
    ], refreshListenable: signedIn);
  }

  @override
  void dispose() {
    router.dispose();
    signedIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: router.config);
}

/// This recipe only permits the local account destination; its guard still runs.
String safeReturnLocation(String? value) {
  try {
    final uri = parseRouteUri(value ?? '/account');
    if (!uri.hasScheme && !uri.hasAuthority && uri.path == '/account') {
      return uri.toString();
    }
  } on FormatException {
    // Fall back instead of letting a malformed return parameter break login.
  }
  return '/account';
}

RouteDefinerRouter recipeRouter(List<RouteDefiner<dynamic>> routes,
        {Listenable? refreshListenable,
        BackButtonDispatcher? backButtonDispatcher}) =>
    RouteDefinerRouter(
      routes: routes,
      refreshListenable: refreshListenable,
      backButtonDispatcher: backButtonDispatcher,
      loadingBuilder: (_) => const pages.LoadingPage(),
      deniedBuilder: (_, __) => const pages.DeniedPage(),
      notFoundBuilder: (_, __) => const pages.NotFoundPage(),
      errorBuilder: (_, __, retry) => pages.ErrorPage(onRetry: retry),
    );

class RetainedTabs extends StatefulWidget {
  const RetainedTabs({super.key, required this.parent});
  final RouteDefinerRouter parent;
  @override
  State<RetainedTabs> createState() => _RetainedTabsState();
}

class _RetainedTabsState extends State<RetainedTabs> {
  late final List<ChildBackButtonDispatcher> dispatchers;
  late final List<RouteDefinerRouter> children;
  var selected = 0;

  @override
  void initState() {
    super.initState();
    dispatchers = List.generate(
        2,
        (_) => widget.parent.config.backButtonDispatcher!
            .createChildBackButtonDispatcher());
    children = List.generate(2, (index) {
      late final RouteDefinerRouter child;
      child = recipeRouter([
        RouteDefiner<void>(
            path: '/',
            builder: (_, __) => Scaffold(
                    body: TextButton(
                  onPressed: () => child.push<void>('/detail'),
                  child: Text('Open tab ${index + 1} detail'),
                ))),
        RouteDefiner<void>(
            path: '/detail',
            builder: (_, __) => Scaffold(
                  appBar: AppBar(title: Text('Tab ${index + 1} detail')),
                  body: TextField(
                      decoration:
                          InputDecoration(labelText: 'Tab ${index + 1} draft')),
                )),
      ], backButtonDispatcher: dispatchers[index]);
      return child;
    });
    dispatchers.first.takePriority();
  }

  @override
  void dispose() {
    for (var i = 0; i < children.length; i++) {
      widget.parent.config.backButtonDispatcher!.forget(dispatchers[i]);
      children[i].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Independent tab stacks')),
        body: IndexedStack(index: selected, children: [
          for (var i = 0; i < children.length; i++)
            TickerMode(
                enabled: i == selected,
                child: Router<RouteStack>.withConfig(
                    config: children[i].nestedConfig)),
        ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (index) {
              setState(() => selected = index);
              dispatchers[index].takePriority();
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'First tab'),
              NavigationDestination(
                  icon: Icon(Icons.star), label: 'Second tab'),
            ]),
      );
}

class DraftEditor extends StatefulWidget {
  const DraftEditor({super.key, required this.router});
  final RouteDefinerRouter router;
  @override
  State<DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<DraftEditor> {
  var dirty = false;
  var asking = false;

  Future<void> leave({bool home = false}) async {
    if (asking) return;
    asking = true;
    final discard = !dirty ||
        await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('Discard your draft?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Keep editing')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Discard')),
                      ],
                    )) ==
            true;
    asking = false;
    if (!mounted || !discard) return;
    setState(() => dirty = false);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (home) {
      widget.router.go('/');
    } else {
      await widget.router.pop<void>();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Draft editor')),
          body: Column(children: [
            TextField(
                onChanged: (_) => setState(() => dirty = true),
                decoration: const InputDecoration(labelText: 'Draft')),
            TextButton(
                onPressed: () => leave(home: true),
                child: const Text('Go home safely')),
          ]),
        ),
      );
}
