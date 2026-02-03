import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/transport/batch_transport.dart';

/// A no-op implementation of [BatchTransport] that silently drops all data.
///
/// Used when the session is not sampled to avoid unnecessary processing.
/// By implementing this in a separate file, we only need to implement the
/// public interface of [BatchTransport], not its private members.
class NoOpBatchTransport implements BatchTransport {
  @override
  void addEvent(Event event) {}

  @override
  void addMeasurement(Measurement measurement) {}

  @override
  void addLog(FaroLog faroLog) {}

  @override
  void addSpan(SpanRecord spanRecord) {}

  @override
  void addExceptions(FaroException exception) {}

  @override
  void updatePayloadMeta(Meta meta) {}

  @override
  Future<void> flush(Payload payload) async {}

  @override
  void checkPayloadItemLimit() {}

  @override
  void dispose() {}

  @override
  bool isPayloadEmpty() => true;

  @override
  int payloadSize() => 0;

  @override
  void resetPayload() {}
}
