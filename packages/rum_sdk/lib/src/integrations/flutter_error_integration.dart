import 'package:flutter/foundation.dart';
import 'package:rum_sdk/rum_flutter.dart';

class FlutterErrorIntegration {
  FlutterExceptionHandler? _defaultOnError;

  FlutterExceptionHandler? _onErrorIntegration;

  void call() {
    _defaultOnError = FlutterError.onError;
    _onErrorIntegration = (FlutterErrorDetails details) async {
      if (details.stack != null) {
        RumFlutter().pushError(
            type: "flutter_error",
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
