import 'dart:ui';

import '../../rum_flutter.dart';

class OnErrorIntegration{

  ErrorCallback? _defaultOnError;
  ErrorCallback? _onErrorIntegration;

  void call(){
    _defaultOnError = PlatformDispatcher.instance.onError;
    _onErrorIntegration = (Object exception, StackTrace stackTrace)  {
      RumFlutter().pushError(type:"flutter_error", value: exception.toString(),stacktrace: stackTrace);
      if(_defaultOnError !=null){
        _defaultOnError!(exception,stackTrace);
      }
      return true;
    };

    PlatformDispatcher.instance.onError = _onErrorIntegration;
  }
  bool isOnErrorSupported(){
    try {
      PlatformDispatcher.instance.onError;
    } on NoSuchMethodError {
      return false;
    } catch (exception, stacktrace) {
      return false;
    }
    return true;
  }

}
