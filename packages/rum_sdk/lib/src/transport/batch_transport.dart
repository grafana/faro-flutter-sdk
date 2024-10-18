import 'dart:async';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/transport/rum_base_transport.dart';

class BatchTransport {
  Payload payload;
  BatchConfig batchConfig;
  List<BaseTransport> transports;
  Timer? flushTimer;
  BatchTransport(
      {required this.payload,
      required this.batchConfig,
      required this.transports}) {
    if (batchConfig.enabled) {
      Timer.periodic(batchConfig.sendTimeout, (Timer t) {
        flushTimer = t;
        flush(payload.toJson());
        resetPayload();
      });
    } else {
      batchConfig.payloadItemLimit = 1;
    }
  }

  Future<void> addEvent(Event event) async {
    payload.events.add(event);
    checkPayloadItemLimit();
  }

  Future<void> addMeasurement(Measurement measurement) async {
    payload.measurements.add(measurement);
    checkPayloadItemLimit();
  }

  Future<void> addLog(RumLog rumLog) async {
    payload.logs.add(rumLog);
    checkPayloadItemLimit();
  }

  Future<void> addExceptions(RumException exception) async {
    payload.exceptions.add(exception);
    checkPayloadItemLimit();
  }

  void updatePayloadMeta(Meta meta) {
    flush(payload.toJson());
    resetPayload();
    payload.meta = meta;
  }

  Future<void> flush(Map<String,dynamic> payload)  async {
    if (isPayloadEmpty()) {
      return;
    }
    if (transports.isNotEmpty) {
      final currentTransports = transports;
      for (var transport in currentTransports) {
        await transport.send(payload);
      }
    }
  }

  void checkPayloadItemLimit() {
    if (payloadSize() >= batchConfig.payloadItemLimit) {
      flush(payload.toJson());
      resetPayload();
    }
  }

  void dispose() {
    flushTimer?.cancel();
  }

  bool isPayloadEmpty() {
    return (payload.events.isEmpty &&
        payload.measurements.isEmpty &&
        payload.logs.isEmpty &&
        payload.exceptions.isEmpty);
  }

  int payloadSize() {
        return (
            payload.logs.length + 
            payload.measurements.length + 
            payload.events.length + 
            payload.exceptions.length 
        );
  }

  void resetPayload() {
    payload.events = [];
    payload.measurements = [];
    payload.logs = [];
    payload.exceptions = [];
  }
}
