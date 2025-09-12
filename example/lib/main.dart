import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';
import 'package:route_definer/src/title_observer.dart';

void main() {
  AppRouter.init(
    GlobalRouteDefiner(
      initialRoute: '/',
      title: 'Route Example',
      unauthorizedBuilder: (_, __) =>
          const Scaffold(body: Center(child: Text("Unauthorized"))),
      onUnknownRoute: (_, __) => MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text("404")),
      ),
    ),
    [
      RouteDefiner(path: '/', builder: (_, __) => const HomePage()),
      RouteDefiner(path: '/about', builder: (_, __) => const AboutPage()),
    ],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppRouter.title,
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      navigatorObservers: [
        TitleObserver(appTitle: TitleObserver.defaultTitleGenerator)
      ],
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/about'),
          child: const Text('Go to About'),
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('About Page')));
  }
}
