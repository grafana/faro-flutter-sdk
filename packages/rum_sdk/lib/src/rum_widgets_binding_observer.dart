import 'package:flutter/cupertino.dart';
import 'package:rum_sdk/src/integrations/native_integration.dart';
import 'package:rum_sdk/rum_sdk.dart';

class RumWidgetsBindingObserver extends WidgetsBindingObserver{
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if(state==AppLifecycleState.resumed){
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        NativeIntegration.instance.getWarmStart();
      });
      NativeIntegration.instance.setWarmStart();
    }
  }
  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
  }

}