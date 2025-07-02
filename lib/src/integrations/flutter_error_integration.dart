import 'package:faro/src/faro.dart';
import 'package:flutter/foundation.dart';

class FlutterErrorIntegration {
  FlutterExceptionHandler? _defaultOnError;

  FlutterExceptionHandler? _onErrorIntegration;

  void call() {
    _defaultOnError = FlutterError.onError;
    _onErrorIntegration = (details) async {
      if (details.stack != null) {
        Faro().pushError(
            type: 'flutter_error',
            value: details.exceptionAsString(),
            stacktrace: details.stack);
      }

      if (_defaultOnError != null) {
        _defaultOnError?.call(details);
      }
    };
    FlutterError.onError = _onErrorIntegration;
  }

  void close() {
    FlutterError.onError = _defaultOnError;
  }
}
