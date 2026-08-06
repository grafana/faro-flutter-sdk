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
    _recordNavigation(
      fromView: route.settings.name,
      toView: previousRoute?.settings.name,
      activitySource: 'navigation.pop',
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _recordNavigation(
      fromView: previousRoute?.settings.name,
      toView: route.settings.name,
      activitySource: 'navigation.push',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _recordNavigation(
      fromView: oldRoute?.settings.name,
      toView: newRoute?.settings.name,
      activitySource: 'navigation.replace',
    );
  }

  void _recordNavigation({
    required String? fromView,
    required String? toView,
    required String activitySource,
  }) {
    if (toView != null) {
      Faro().setViewMeta(name: toView);
    }
    if (fromView != null || toView != null) {
      Faro().pushEvent(
        'view_changed',
        attributes: {'fromView': fromView, 'toView': toView},
      );
    }
    _lifecycleSignalChannel.emitActivity(source: activitySource);
  }
}
