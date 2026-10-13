import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer_example/recipes.dart';

void main() => runApp(const NativeCheckApp());

/// Native fixture: custom-scheme links, typed results and Cupertino swipe-back.
class NativeCheckApp extends StatefulWidget {
  const NativeCheckApp({super.key});
  @override
  State<NativeCheckApp> createState() => NativeCheckAppState();
}

class NativeCheckAppState extends State<NativeCheckApp> {
  late final RouteDefinerRouter router;
  late final RouteDefiner<int> item;
  int? selected;

  @override
  void initState() {
    super.initState();
    item = RouteDefiner<int>(
      path: '/item/:id',
      pageRouteFactory: RouteFactories.cupertino,
      builder: (_, state) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Item')),
        child: Center(
            child: CupertinoButton(
          onPressed: () => router.pop<int>(state.pathInt('id')),
          child: Text('Select ${state.pathInt('id')}'),
        )),
      ),
    );
    router = RouteDefinerRouter(
      restorationScopeId: 'native-navigation',
      routes: [
        RouteDefiner<void>(
            path: '/',
            builder: (_, __) => Scaffold(
                  appBar: AppBar(title: const Text('Native routing checks')),
                  body: Column(children: [
                    Text('Selected: $selected'),
                    TextButton(
                        onPressed: () async {
                          final value = await router
                              .pushRoute(item, parameters: {'id': '7'});
                          if (mounted) setState(() => selected = value);
                        },
                        child: const Text('Open item')),
                    TextButton(
                        onPressed: () => router.push<void>('/editor'),
                        child: const Text('Open editor')),
                  ]),
                )),
        item,
        RouteDefiner<void>(
            path: '/editor', builder: (_, __) => DraftEditor(router: router)),
      ],
      loadingBuilder: (_) => const Text('Loading'),
      deniedBuilder: (_, __) => const Text('Denied'),
      notFoundBuilder: (_, state) => Text('Unknown ${state.uri}'),
      errorBuilder: (_, __, retry) =>
          TextButton(onPressed: retry, child: const Text('Retry')),
    );
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        restorationScopeId: 'native-app',
        routerConfig: router.config,
      );
}
