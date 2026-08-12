import 'dart:async';

import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/session/app_lifecycle_service.dart';
import 'package:flutter/cupertino.dart';

class FaroWidgetsBindingObserver extends WidgetsBindingObserver {
  FaroWidgetsBindingObserver({
    required AppLifecycleService appLifecycleService,
    required NativeIntegration nativeIntegration,
    required Future<void> Function() onAppBackgrounded,
  }) : _appLifecycleService = appLifecycleService,
       _nativeIntegration = nativeIntegration,
       _onAppBackgrounded = onAppBackgrounded;

  final AppLifecycleService _appLifecycleService;
  final NativeIntegration _nativeIntegration;
  final Future<void> Function() _onAppBackgrounded;
  AppLifecycleState? _previousState;

  /// Whether the app has left the foreground since it last resumed.
  ///
  /// A warm start is the app coming back from the background, so there has to
  /// have been a background to come back from. Without this the `resumed`
  /// callback that merely completes app launch is measured as a warm start of
  /// a few milliseconds, on top of the cold start for the same launch.
  bool _hasLeftForeground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Keep the shared foreground state current; see AppLifecycleService
    // for how it is used.
    _appLifecycleService.updateFromLifecycleState(state);
    if (_isOutOfForeground(state)) {
      _hasLeftForeground = true;
    } else if (state == AppLifecycleState.resumed && _hasLeftForeground) {
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
    if (state != AppLifecycleState.resumed) {
      unawaited(_onAppBackgrounded());
    }
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
