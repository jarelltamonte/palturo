import 'package:flutter/widgets.dart';

/// Single global navigator handle shared by the app shell and services that
/// need to route from outside a widget tree (notifications, deep links).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Lets Activity/Requests know when another route covers them, so banner
/// suppression follows what the user can actually see.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
