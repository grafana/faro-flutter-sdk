import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter/widgets.dart';

class FaroNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  factory FaroNavigationObserver() {
    return FaroNavigationObserver._(
      lifecycleSignalChannel: pod.resolve(
        userActionLifecycleSignalChannelProvider,
      ),
    );
  }

  FaroNavigationObserver._({
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
  }) : _lifecycleSignalChannel = lifecycleSignalChannel;

  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    Faro().setViewMeta(name: previousRoute?.settings.name);
    Faro().pushEvent(
      'view_changed',
      attributes: {
        'fromView': route.settings.name,
        'toView': previousRoute?.settings.name,
      },
    );
    _lifecycleSignalChannel.emitActivity(source: 'navigation.pop');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    Faro().setViewMeta(name: route.settings.name);
    Faro().pushEvent(
      'view_changed',
      attributes: {
        'fromView': previousRoute?.settings.name,
        'toView': route.settings.name,
      },
    );
    _lifecycleSignalChannel.emitActivity(source: 'navigation.push');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    Faro().setViewMeta(name: newRoute?.settings.name);
    Faro().pushEvent(
      'view_changed',
      attributes: {
        'fromView': oldRoute?.settings.name,
        'toView': newRoute?.settings.name,
      },
    );
    _lifecycleSignalChannel.emitActivity(source: 'navigation.replace');
  }
}
