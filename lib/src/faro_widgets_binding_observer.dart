import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:flutter/cupertino.dart';

class FaroWidgetsBindingObserver extends WidgetsBindingObserver {
  FaroWidgetsBindingObserver({
    required NativeIntegration nativeIntegration,
    required SessionManager sessionManager,
  }) : _nativeIntegration = nativeIntegration,
       _sessionManager = sessionManager;

  final NativeIntegration _nativeIntegration;
  final SessionManager _sessionManager;
  AppLifecycleState? _previousState;

  /// Whether the app has left the foreground since it last resumed.
  ///
  /// A foreground return is meaningful session activity and may also be a warm
  /// start. Requiring a prior background state excludes the `resumed` callback
  /// that merely completes app launch and transient focus changes.
  bool _hasLeftForeground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isOutOfForeground(state)) {
      _hasLeftForeground = true;
    } else if (state == AppLifecycleState.resumed && _hasLeftForeground) {
      _sessionManager.checkSession(activity: SessionActivityKind.meaningful);
      _hasLeftForeground = false;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _nativeIntegration.getWarmStart();
      });
      _nativeIntegration.setWarmStart();
    }

    Faro().pushEvent(
      'app_lifecycle_changed',
      attributes: {
        'fromState': _previousState?.name ?? '',
        'toState': state.name,
      },
    );
    _previousState = state;
  }

  /// Whether [state] means the app is no longer showing.
  ///
  /// `inactive` is excluded on purpose: the app is still frontmost and merely
  /// not receiving events, which is what a notification banner or a glance at
  /// the app switcher looks like. Returning from one of those is not a warm
  /// start. `detached` is excluded because an app that comes back from it
  /// starts over, which is a cold start.
  static bool _isOutOfForeground(AppLifecycleState state) =>
      state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
}
