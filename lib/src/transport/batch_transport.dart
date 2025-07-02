// ignore_for_file: use_setters_to_change_properties

import 'dart:async';
import 'package:faro/faro_sdk.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/util/payload_extension.dart';
import 'package:flutter/foundation.dart';

class BatchTransport {
  BatchTransport(
      {required this.payload,
      required this.batchConfig,
      required this.transports}) {
    if (batchConfig.enabled) {
      Timer.periodic(batchConfig.sendTimeout, (t) {
        flushTimer = t;
        flush(payload);
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

  void addEvent(Event event) {
    payload.events.add(event);
    checkPayloadItemLimit();
  }

  void addMeasurement(Measurement measurement) {
    payload.measurements.add(measurement);
    checkPayloadItemLimit();
  }

  void addLog(FaroLog faroLog) {
    payload.logs.add(faroLog);
    checkPayloadItemLimit();
  }

  void addSpan(SpanRecord spanRecord) {
    payload.traces.addSpan(spanRecord);
    checkPayloadItemLimit();
  }

  void addExceptions(FaroException exception) {
    payload.exceptions.add(exception);
    checkPayloadItemLimit();
  }

  void updatePayloadMeta(Meta meta) {
    flush(payload);
    resetPayload();
    payload.meta = meta;
  }

  Future<void> flush(Payload payload) async {
    if (payload.isEmpty()) {
      return;
    }
    final payloadJson = payload.toJson();
    if (payloadJson.isEmpty) {
      return;
    }

    if (transports.isNotEmpty) {
      final currentTransports = transports;
      for (final transport in currentTransports) {
        await transport.send(payloadJson);
      }
    }
  }

  void checkPayloadItemLimit() {
    if (payloadSize() >= batchConfig.payloadItemLimit) {
      flush(payload);
      resetPayload();
    }
  }

  void dispose() {
    flushTimer?.cancel();
  }

  bool isPayloadEmpty() {
    return payload.isEmpty();
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

class BatchTransportFactory {
  static BatchTransport? _instance;

  BatchTransport? get instance => _instance;

  BatchTransport create({
    required Payload initialPayload,
    required BatchConfig batchConfig,
    required List<BaseTransport> transports,
  }) {
    if (_instance != null) {
      return _instance!;
    }

    final instance = BatchTransport(
        payload: initialPayload,
        batchConfig: batchConfig,
        transports: transports);

    _instance = instance;
    return instance;
  }

  /// Reset the singleton instance. This is primarily for testing purposes.
  @visibleForTesting
  void reset() {
    _instance = null;
  }

  /// Set the singleton instance. This is primarily for testing purposes.
  @visibleForTesting
  void setInstance(BatchTransport instance) {
    _instance = instance;
  }
}
