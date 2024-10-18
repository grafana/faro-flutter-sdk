import 'package:rum_sdk/rum_flutter.dart';


class RunZonedIntegration{
  static void runZonedOnError(Object exception, StackTrace stackTrace){
    RumFlutter().pushError(type:"flutter_error",value: exception.toString(), stacktrace: stackTrace);
  }
}
