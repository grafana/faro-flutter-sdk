import 'dart:developer';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/navigation/tracked_router_registry.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Records view changes for the Navigator it is attached to.
///
/// Under a router tracked by a `FaroRouterTracker`, router pages are left to
/// the tracker, so the two do not record the same change twice. Dialogs and
/// `Navigator.push` routes on those Navigators are still recorded here.
///
/// Set [deferToRouterTracker] to false on an observer whose Navigator changes
/// pages without the router noticing, for example a step-by-step flow with
/// its own `Navigator(pages: ...)` inside a router page.
class FaroNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  /// Creates an observer.
  ///
  /// With [deferToRouterTracker] set to false, this observer records every
  /// route change, even under a tracked router.
  factory FaroNavigationObserver({bool deferToRouterTracker = true}) {
    return FaroNavigationObserver._(
      lifecycleSignalChannel: pod.resolve(
        userActionLifecycleSignalChannelProvider,
      ),
      sessionManager: pod.resolve(sessionManagerProvider),
      trackedRouters: deferToRouterTracker
          ? pod.resolve(trackedRouterRegistryProvider)
          : null,
      logDeferral: pod.resolve(navigationObserverDeferralLoggerProvider),
    );
  }

  FaroNavigationObserver._({
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
    required SessionManager sessionManager,
    required TrackedRouterRegistry? trackedRouters,
    required VoidCallback logDeferral,
  }) : _lifecycleSignalChannel = lifecycleSignalChannel,
       _sessionManager = sessionManager,
       _trackedRouters = trackedRouters,
       _logDeferral = logDeferral;

  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;
  final SessionManager _sessionManager;
  final TrackedRouterRegistry? _trackedRouters;
  final VoidCallback _logDeferral;
  bool _hasLoggedDeferral = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _recordNavigation(
      from: route,
      to: previousRoute,
      opened: null,
      closed: route,
      activitySource: 'navigation.pop',
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _recordNavigation(
      from: previousRoute,
      to: route,
      opened: route,
      closed: null,
      activitySource: 'navigation.push',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _recordNavigation(
      from: oldRoute,
      to: newRoute,
      opened: newRoute,
      closed: oldRoute,
      activitySource: 'navigation.replace',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    for (final view in _trackedViews()) {
      view.pagelessRouteClosed(route);
    }
  }

  /// Records a view change unless a router tracker covers it.
  ///
  /// Under a tracked router, page routes belong to the tracker. Pageless
  /// routes are invisible to the tracker, so they are still recorded here,
  /// naming the page side with the tracker's view to keep one naming style.
  void _recordNavigation({
    required Route<dynamic>? from,
    required Route<dynamic>? to,
    required Route<dynamic>? opened,
    required Route<dynamic>? closed,
    required String activitySource,
  }) {
    _sessionManager.checkSession(activity: SessionActivityKind.meaningful);
    final views = _trackedViews();
    if (views.isEmpty) {
      _record(from?.settings.name, to?.settings.name);
      _lifecycleSignalChannel.emitActivity(source: activitySource);
      return;
    }

    for (final view in views) {
      view.pagelessRouteClosed(closed);
      if (opened != null && !_isPage(opened)) {
        view.pagelessRouteOpened(opened);
      }
    }

    final changedRoute = opened ?? closed;
    if (_isPage(changedRoute) && (to == null || _isPage(to))) {
      if (opened != null && from != null && !_isPage(from)) {
        // A router page now covers a pageless route. The tracker records it.
        for (final view in views) {
          view.pendingChangeCoversPagelessRoute();
        }
      }
      _logDeferralOnce();
      _lifecycleSignalChannel.emitActivity(source: activitySource);
      return;
    }

    // The page that was visible keeps the last recorded router view. The
    // page that becomes visible is read from the router now, because a
    // router change in the same frame may still be pending.
    final tracked = views.last;
    var fromView = from?.settings.name;
    if (_isPage(from)) fromView = tracked.routerView ?? fromView;
    var toView = to?.settings.name;
    if (_isPage(to)) toView = tracked.currentRouterView ?? toView;

    // The tracker may already have recorded a router change made while a
    // pageless route was on top. Closing that route then shows the same view,
    // so only the view metadata is restored, in case an observer on another
    // Navigator changed it in between.
    final alreadyRecorded =
        _isPage(to) && views.every((view) => view.visibleView == toView);
    if (!alreadyRecorded) {
      _record(fromView, toView);
    } else if (toView != null) {
      Faro().setViewMeta(name: toView);
    }
    for (final view in views) {
      view.visibleView = toView;
      // A router page is visible again, even if the tracker has not yet
      // recorded a router change from this frame.
      if (_isPage(to)) view.routerView = toView;
      if (_isPage(changedRoute)) {
        // A router page was removed and revealed a pageless route. The
        // tracker was notified first and is waiting; this event replaces its
        // own.
        view.claimPendingChange();
      }
    }
    _lifecycleSignalChannel.emitActivity(source: activitySource);
  }

  List<TrackedRouterView> _trackedViews() =>
      _trackedRouters?.viewsFor(navigator) ?? const [];

  void _record(String? fromView, String? toView) {
    if (toView != null) {
      Faro().setViewMeta(name: toView);
    }
    if (fromView != null || toView != null) {
      Faro().pushEvent(
        'view_changed',
        attributes: {'fromView': fromView, 'toView': toView},
      );
    }
  }

  void _logDeferralOnce() {
    if (_hasLoggedDeferral) return;
    _hasLoggedDeferral = true;
    _logDeferral();
  }

  static bool _isPage(Route<dynamic>? route) => route?.settings is Page;
}

/// Debug-only diagnostic for an observer that leaves pages to a tracker.
@visibleForTesting
final navigationObserverDeferralLoggerProvider = Provider<VoidCallback>((_) {
  return () {
    if (!kDebugMode) return;
    log(
      'Faro: FaroNavigationObserver found a FaroRouterTracker on this router '
      'and leaves router pages to it. It still records dialogs and '
      'Navigator.push routes.',
    );
  };
});
