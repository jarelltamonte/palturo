import 'package:flutter/widgets.dart';

/// Single global navigator handle shared by the app shell and services that
/// need to route from outside a widget tree (notifications, deep links).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
