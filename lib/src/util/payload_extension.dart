import 'package:faro/src/models/models.dart';

extension PayloadX on Payload {
  bool isEmpty() {
    return events.isEmpty &&
        measurements.isEmpty &&
        logs.isEmpty &&
        exceptions.isEmpty &&
        traces.hasNoTraces();
  }
}
