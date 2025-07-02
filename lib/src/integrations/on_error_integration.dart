import 'dart:ui';

import 'package:faro/src/faro.dart';

class OnErrorIntegration {
  ErrorCallback? _defaultOnError;
  ErrorCallback? _onErrorIntegration;

  void call() {
    _defaultOnError = PlatformDispatcher.instance.onError;
    _onErrorIntegration = (exception, stackTrace) {
      Faro().pushError(
          type: 'flutter_error',
          value: exception.toString(),
          stacktrace: stackTrace);
      if (_defaultOnError != null) {
        _defaultOnError?.call(exception, stackTrace);
      }
      return true;
    };

    PlatformDispatcher.instance.onError = _onErrorIntegration;
  }

  bool isOnErrorSupported() {
    try {
      PlatformDispatcher.instance.onError;
      // ignore: avoid_catching_errors
    } on NoSuchMethodError {
      return false;
    } catch (exception) {
      return false;
    }
    return true;
  }
}
