import 'dart:developer';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/navigation/tracked_router_registry.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Diagnostic sink for verifying extractor failure and recovery behavior.
@visibleForTesting
final routerTrackerErrorLoggerProvider =
    Provider<void Function(Object, StackTrace)>((_) {
      return (error, stackTrace) => log(
        'Faro: viewNameExtractor threw; skipping this view change.',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );
    });

/// Tracks resolved views across root and nested navigators with one listener.
///
/// Pass the router's delegate as [routeChanges]. [viewNameExtractor] reads the
/// resolved visible view. Return null or an empty string while the router is
/// uninitialized or to skip a view. Skipped views preserve the previous name;
/// consecutive identical names emit no additional view events. Notifications
/// still count as session and user-action activity.
///
/// Extractor exceptions are treated as skipped views. A diagnostic is logged
/// once per consecutive failure period, and tracking resumes after recovery.
/// The initial view is recorded immediately when available.
///
/// `FaroNavigationObserver`s on Navigators under this router leave router
/// pages to the tracker and still record dialogs and `Navigator.push` routes,
/// so keeping them next to the tracker does not duplicate events. This relies
/// on [routeChanges] being the delegate of the `Router` widget.
///
/// Call [dispose] before disposing the router; the caller retains ownership of
/// [routeChanges].
class FaroRouterTracker {
  /// Starts tracking the router and records its initial resolved view, if any.
  FaroRouterTracker({
    required Listenable routeChanges,
    required ValueGetter<String?> viewNameExtractor,
  }) : _routeChanges = routeChanges,
       _viewNameExtractor = viewNameExtractor,
       _sessionManager = pod.resolve(sessionManagerProvider),
       _lifecycleSignalChannel = pod.resolve(
         userActionLifecycleSignalChannelProvider,
       ),
       _logExtractorError = pod.resolve(routerTrackerErrorLoggerProvider) {
    _releaseRegistration = pod
        .resolve(trackedRouterRegistryProvider)
        .register(_routeChanges, _view);
    _routeChanges.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  final Listenable _routeChanges;
  final ValueGetter<String?> _viewNameExtractor;
  final SessionManager _sessionManager;
  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;
  final void Function(Object, StackTrace) _logExtractorError;
  late final TrackedRouterView _view = TrackedRouterView(
    resolveCurrentView: () {
      final name = _extractViewName();
      return name == null || name.isEmpty ? null : name;
    },
  );
  late final VoidCallback _releaseRegistration;
  bool _hasLoggedExtractorError = false;
  bool _isDisposed = false;

  String? _extractViewName() {
    try {
      final name = _viewNameExtractor();
      _hasLoggedExtractorError = false;
      return name;
    } catch (error, stackTrace) {
      if (!_hasLoggedExtractorError) {
        _hasLoggedExtractorError = true;
        _logExtractorError(error, stackTrace);
      }
      return null;
    }
  }

  void _onRouteChanged() {
    if (_isDisposed) return;
    _sessionManager.checkSession(activity: SessionActivityKind.meaningful);
    if (_view.hasOpenPagelessRoutes) {
      // This change might reveal a dialog or a Navigator.push route. Wait
      // until the Navigator applied it, so the observer can record the
      // visible view first. A post-frame callback registered now runs
      // before ones the new page adds, such as opening a dialog on load.
      if (_view.beginPendingChange()) {
        final routerViewBefore = _view.routerView;
        SchedulerBinding.instance
          ..addPostFrameCallback((_) => _recordPendingChange(routerViewBefore))
          ..ensureVisualUpdate();
      }
    } else {
      _recordView(emit: true);
    }
    _lifecycleSignalChannel.emitActivity(source: 'navigation.router');
  }

  void _recordPendingChange(String? routerViewBefore) {
    final change = _view.endPendingChange();
    if (_isDisposed) return;
    _recordView(
      emit: change != PendingRouterChange.claimed,
      // An observer may have updated routerView to the new page during the
      // frame. The router still changed, so it counts as a new view.
      coversPagelessRoute:
          change == PendingRouterChange.coversPagelessRoute ||
          _view.currentRouterView != routerViewBefore,
    );
  }

  void _recordView({required bool emit, bool coversPagelessRoute = false}) {
    final name = _extractViewName();
    if (name == null || name.isEmpty) return;
    final isNewRouterView = name != _view.routerView;
    // A router page with the same name as before still counts when it now
    // covers a pageless route that was visible.
    final coversOtherView = coversPagelessRoute && name != _view.visibleView;
    if (!isNewRouterView && !coversOtherView) return;
    _view.routerView = name;
    // An observer may already have recorded this view, for example when a
    // dialog closed onto it before the tracker's deferred update.
    if (!emit || name == _view.visibleView) return;
    final previousName = _view.visibleView;
    _view.visibleView = name;
    Faro().setViewMeta(name: name);
    Faro().pushEvent(
      'view_changed',
      attributes: {'fromView': previousName, 'toView': name},
    );
  }

  /// Stops tracking and removes this tracker's listener.
  ///
  /// Safe to call more than once. This does not dispose the router.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _routeChanges.removeListener(_onRouteChanged);
    _releaseRegistration();
  }
}
