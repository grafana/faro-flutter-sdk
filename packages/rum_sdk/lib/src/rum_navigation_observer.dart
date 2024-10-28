import 'package:flutter/widgets.dart';
import 'package:rum_sdk/rum_sdk.dart';

class RumNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    RumFlutter().setViewMeta(name: previousRoute?.settings.name);
    RumFlutter().pushEvent('view_changed', attributes: {
      'fromView': route.settings.name,
      'toView': previousRoute?.settings.name,
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    RumFlutter().setViewMeta(name: route.settings.name);
    RumFlutter().pushEvent('view_changed', attributes: {
      'fromView': previousRoute?.settings.name,
      'toView': route.settings.name,
    });
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    RumFlutter().setViewMeta(name: newRoute?.settings.name);
    RumFlutter().pushEvent('view_changed', attributes: {
      'fromView': oldRoute?.settings.name,
      'toView': newRoute?.settings.name,
    });
  }
}
