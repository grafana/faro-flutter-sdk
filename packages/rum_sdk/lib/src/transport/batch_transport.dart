import 'dart:async';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/models/span_record.dart';

class BatchTransport {
  BatchTransport(
      {required this.payload,
      required this.batchConfig,
      required this.transports}) {
    if (batchConfig.enabled) {
      Timer.periodic(batchConfig.sendTimeout, (t) {
        flushTimer = t;
        flush(payload.toJson());
        resetPayload();
      });
    } else {
      batchConfig.payloadItemLimit = 1;
    }
  }
  Payload payload;
  BatchConfig batchConfig;
  List<BaseTransport> transports;
  Timer? flushTimer;

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

  Future<void> addSpan(SpanRecord spanRecord) async {
    payload.traces.addSpan(spanRecord);
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

  Future<void> flush(Map<String, dynamic> payload) async {
    if (isPayloadEmpty()) {
      return;
    }
    if (transports.isNotEmpty) {
      final currentTransports = transports;
      for (final transport in currentTransports) {
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
    return payload.events.isEmpty &&
        payload.measurements.isEmpty &&
        payload.logs.isEmpty &&
        payload.exceptions.isEmpty &&
        payload.traces.hasNoTraces();
  }

  int payloadSize() {
    return payload.logs.length +
        payload.measurements.length +
        payload.events.length +
        payload.exceptions.length +
        payload.traces.numberSpans();
  }

  void resetPayload() {
    payload.events = [];
    payload.measurements = [];
    payload.logs = [];
    payload.exceptions = [];
    payload.traces.resetSpans();
  }
}
