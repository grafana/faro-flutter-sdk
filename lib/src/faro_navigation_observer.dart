import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter/widgets.dart';

/// Tracks named Navigator routes or resolved router state changes.
///
/// Use [FaroNavigationObserver] for a plain Navigator. Use
/// [FaroNavigationObserver.router] for nested router navigation, including
/// stateful branch switches that do not push or pop a Navigator route.
class FaroNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  /// Creates an observer to register with a Navigator's observers.
  factory FaroNavigationObserver() {
    return FaroNavigationObserver._(
      lifecycleSignalChannel: pod.resolve(
        userActionLifecycleSignalChannelProvider,
      ),
      sessionManager: pod.resolve(sessionManagerProvider),
    );
  }

  /// Tracks resolved router changes without depending on a router package.
  ///
  /// Pass the router's delegate as [routeChanges]. [viewNameExtractor] reads
  /// the resolved visible view; return null or an empty string while the
  /// router is uninitialized or to skip a route. Skipped routes preserve the
  /// previous view. Consecutive identical names emit no additional events.
  ///
  /// The initial view is recorded immediately when available. This observer
  /// ignores Navigator callbacks in router mode, so registering this same
  /// instance on a Navigator does not duplicate router telemetry. Do not
  /// combine it with separate Faro navigation observers.
  ///
  /// Call [dispose] before disposing the router. This removes only Faro's
  /// listener; the caller retains ownership of [routeChanges].
  factory FaroNavigationObserver.router({
    required Listenable routeChanges,
    required ValueGetter<String?> viewNameExtractor,
  }) {
    final observer = FaroNavigationObserver._(
      lifecycleSignalChannel: pod.resolve(
        userActionLifecycleSignalChannelProvider,
      ),
      sessionManager: pod.resolve(sessionManagerProvider),
      routeChanges: routeChanges,
      viewNameExtractor: viewNameExtractor,
    );
    routeChanges.addListener(observer._onRouteChanged);
    try {
      observer._onRouteChanged();
    } catch (_) {
      observer.dispose();
      rethrow;
    }
    return observer;
  }

  FaroNavigationObserver._({
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
    required SessionManager sessionManager,
    Listenable? routeChanges,
    ValueGetter<String?>? viewNameExtractor,
  }) : _lifecycleSignalChannel = lifecycleSignalChannel,
       _sessionManager = sessionManager,
       _routeChanges = routeChanges,
       _viewNameExtractor = viewNameExtractor;

  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;
  final SessionManager _sessionManager;
  final Listenable? _routeChanges;
  final ValueGetter<String?>? _viewNameExtractor;
  String? _lastViewName;
  bool _isDisposed = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _recordNavigatorNavigation(
      fromView: route.settings.name,
      toView: previousRoute?.settings.name,
      activitySource: 'navigation.pop',
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _recordNavigatorNavigation(
      fromView: previousRoute?.settings.name,
      toView: route.settings.name,
      activitySource: 'navigation.push',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _recordNavigatorNavigation(
      fromView: oldRoute?.settings.name,
      toView: newRoute?.settings.name,
      activitySource: 'navigation.replace',
    );
  }

  void _onRouteChanged() {
    if (_isDisposed) return;
    final name = _viewNameExtractor?.call();
    if (name == null || name.isEmpty || name == _lastViewName) return;
    final previousName = _lastViewName;
    _lastViewName = name;
    _recordNavigation(
      fromView: previousName,
      toView: name,
      activitySource: 'navigation.router',
    );
  }

  void _recordNavigatorNavigation({
    required String? fromView,
    required String? toView,
    required String activitySource,
  }) {
    if (_routeChanges != null) return;
    _recordNavigation(
      fromView: fromView,
      toView: toView,
      activitySource: activitySource,
    );
  }

  void _recordNavigation({
    required String? fromView,
    required String? toView,
    required String activitySource,
  }) {
    if (_isDisposed) return;
    _sessionManager.checkSession(activity: SessionActivityKind.meaningful);
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

  /// Stops tracking and removes the router listener, if any.
  ///
  /// Safe to call more than once. This does not dispose the router.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _routeChanges?.removeListener(_onRouteChanged);
  }
}
