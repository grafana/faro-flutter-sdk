import 'package:faro/faro_sdk.dart';
import 'package:flutter/widgets.dart';

class FaroNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    Faro().setViewMeta(name: previousRoute?.settings.name);
    Faro().pushEvent('view_changed', attributes: {
      'fromView': route.settings.name,
      'toView': previousRoute?.settings.name,
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    Faro().setViewMeta(name: route.settings.name);
    Faro().pushEvent('view_changed', attributes: {
      'fromView': previousRoute?.settings.name,
      'toView': route.settings.name,
    });
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    Faro().setViewMeta(name: newRoute?.settings.name);
    Faro().pushEvent('view_changed', attributes: {
      'fromView': oldRoute?.settings.name,
      'toView': newRoute?.settings.name,
    });
  }
}
