import 'package:flutter/material.dart';
import 'package:route_definer/route_definer.dart';



class TitleObserver extends NavigatorObserver {
  static String Function(String, String?) defaultTitleGenerator = (appName, routeName) => (routeName?.isEmpty ?? true) ? appName : "$appName | $routeName";
  late String Function(String appName, String? routeName) appTitle;
  TitleObserver({ required this.appTitle });

  @override
  void didPush(Route route, Route? previousRoute) {
    _updateTitle(route.settings);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) _updateTitle(newRoute.settings);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute != null) _updateTitle(previousRoute.settings);
  }

  void _updateTitle(RouteSettings settings) async {
    try {
      final definer = AppRouter.analyzeRoute(settings);
      final titleFn = definer.match?.title;
      if (titleFn != null) {
        final title = await titleFn();
        updateBrowserTitle(appTitle(AppRouter.title, title));
      } else {
        updateBrowserTitle(appTitle(AppRouter.title, null));
      }
    } catch (_) {
      updateBrowserTitle(AppRouter.title);
    }
  }
}
