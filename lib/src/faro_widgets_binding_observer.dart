import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:flutter/cupertino.dart';

class FaroWidgetsBindingObserver extends WidgetsBindingObserver {
  AppLifecycleState? _previousState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        resolvedPlatformInfoProvider.supportsNativeIntegration) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        NativeIntegration.instance.getWarmStart();
      });
      NativeIntegration.instance.setWarmStart();
    }

    Faro().pushEvent('app_lifecycle_changed', attributes: {
      'fromState': _previousState?.name ?? '',
      'toState': state.name,
    });
    _previousState = state;
  }
}
