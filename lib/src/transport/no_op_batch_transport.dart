import 'package:faro/src/device_info/dynamic_device_state_provider.dart';
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
  void addEvent(Event event, {DynamicDeviceStateCapture? capture}) {}

  @override
  void addMeasurement(
    Measurement measurement, {
    DynamicDeviceStateCapture? capture,
  }) {}

  @override
  void addLog(FaroLog faroLog, {DynamicDeviceStateCapture? capture}) {}

  @override
  void addSpan(SpanRecord spanRecord, {DynamicDeviceStateCapture? capture}) {}

  @override
  void addExceptions(
    FaroException exception, {
    DynamicDeviceStateCapture? capture,
  }) {}

  @override
  DynamicDeviceStateCapture? captureDynamicDeviceState() => null;

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
