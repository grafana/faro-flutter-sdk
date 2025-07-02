import 'package:faro/src/faro.dart';

class RunZonedIntegration {
  static void runZonedOnError(Object exception, StackTrace stackTrace) {
    Faro().pushError(
      type: 'flutter_error',
      value: exception.toString(),
      stacktrace: stackTrace,
    );
  }
}
