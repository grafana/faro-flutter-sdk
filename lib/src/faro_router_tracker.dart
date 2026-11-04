import 'dart:developer';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter/foundation.dart';

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
/// Use this tracker instead of separate Faro navigation observers on the root
/// or nested navigators. Call [dispose] before disposing the router; the caller
/// retains ownership of [routeChanges].
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
    _routeChanges.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  final Listenable _routeChanges;
  final ValueGetter<String?> _viewNameExtractor;
  final SessionManager _sessionManager;
  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;
  final void Function(Object, StackTrace) _logExtractorError;
  String? _lastViewName;
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
    final name = _extractViewName();
    _sessionManager.checkSession(activity: SessionActivityKind.meaningful);
    if (name != null && name.isNotEmpty && name != _lastViewName) {
      final previousName = _lastViewName;
      _lastViewName = name;
      Faro().setViewMeta(name: name);
      Faro().pushEvent(
        'view_changed',
        attributes: {'fromView': previousName, 'toView': name},
      );
    }
    _lifecycleSignalChannel.emitActivity(source: 'navigation.router');
  }

  /// Stops tracking and removes this tracker's listener.
  ///
  /// Safe to call more than once. This does not dispose the router.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _routeChanges.removeListener(_onRouteChanged);
  }
}
