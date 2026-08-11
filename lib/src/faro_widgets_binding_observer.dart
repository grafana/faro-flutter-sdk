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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Keep the shared foreground state current; see AppLifecycleService
    // for how it is used.
    _appLifecycleService.updateFromLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
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
}
