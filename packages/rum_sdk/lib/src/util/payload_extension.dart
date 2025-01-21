import 'package:rum_sdk/rum_sdk.dart';

extension PayloadX on Payload {
  bool isEmpty() {
    return events.isEmpty &&
        measurements.isEmpty &&
        logs.isEmpty &&
        exceptions.isEmpty &&
        traces.hasNoTraces();
  }
}
