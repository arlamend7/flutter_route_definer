/// A flexible routing system for Flutter with support for guards, dynamic paths, and authorization.
///
/// This library provides [RouteDefiner], [RouteGuard], and [AppRouter] to build
/// modular and testable navigation flows.
library route_definer;

export 'src/app_router.dart';
export 'src/route_definer.dart';
export 'src/route_guard.dart';
export 'src/route_state.dart';
export 'src/global_route_definer.dart';
export 'src/route_options.dart';
export 'src/current_route.dart';
export 'src/deafault_guard_handler_page.dart';
export 'src/title_observer.dart';
export 'navigations/title_updater_stub.dart'
    if (dart.library.html) 'navigations/title_updater.dart';
