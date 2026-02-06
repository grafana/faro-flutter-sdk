// ignore_for_file: use_setters_to_change_properties

import 'dart:async';

import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/no_op_batch_transport.dart';
import 'package:faro/src/util/payload_extension.dart';
import 'package:flutter/foundation.dart';

/// Transport that batches telemetry data and sends it periodically.
class BatchTransport {
  BatchTransport({
    required Payload payload,
    required BatchConfig batchConfig,
    required List<BaseTransport> transports,
  })  : _payload = payload,
        _batchConfig = batchConfig,
        _transports = transports {
    if (_batchConfig.enabled) {
      _flushTimer = Timer.periodic(_batchConfig.sendTimeout, (_) {
        flush(_payload);
        resetPayload();
      });
    } else {
      _batchConfig.payloadItemLimit = 1;
    }
  }

  final Payload _payload;
  final BatchConfig _batchConfig;
  final List<BaseTransport> _transports;
  Timer? _flushTimer;

  void addEvent(Event event) {
    _payload.events.add(event);
    checkPayloadItemLimit();
  }

  void addMeasurement(Measurement measurement) {
    _payload.measurements.add(measurement);
    checkPayloadItemLimit();
  }

  void addLog(FaroLog faroLog) {
    _payload.logs.add(faroLog);
    checkPayloadItemLimit();
  }

  void addSpan(SpanRecord spanRecord) {
    _payload.traces.addSpan(spanRecord);
    checkPayloadItemLimit();
  }

  void addExceptions(FaroException exception) {
    _payload.exceptions.add(exception);
    checkPayloadItemLimit();
  }

  void updatePayloadMeta(Meta meta) {
    flush(_payload);
    resetPayload();
    _payload.meta = meta;
  }

  Future<void> flush(Payload payload) async {
    if (payload.isEmpty()) {
      return;
    }
    final payloadJson = payload.toJson();
    if (payloadJson.isEmpty) {
      return;
    }

    if (_transports.isNotEmpty) {
      final currentTransports = _transports;
      for (final transport in currentTransports) {
        await transport.send(payloadJson);
      }
    }
  }

  void checkPayloadItemLimit() {
    if (payloadSize() >= _batchConfig.payloadItemLimit) {
      flush(_payload);
      resetPayload();
    }
  }

  void dispose() {
    _flushTimer?.cancel();
  }

  bool isPayloadEmpty() {
    return _payload.isEmpty();
  }

  int payloadSize() {
    return _payload.logs.length +
        _payload.measurements.length +
        _payload.events.length +
        _payload.exceptions.length +
        _payload.traces.numberSpans();
  }

  void resetPayload() {
    _payload.events = [];
    _payload.measurements = [];
    _payload.logs = [];
    _payload.exceptions = [];
    _payload.traces.resetSpans();
  }
}

class BatchTransportFactory {
  static BatchTransport? _instance;

  BatchTransport? get instance => _instance;

  BatchTransport create({
    required Payload initialPayload,
    required BatchConfig batchConfig,
    required List<BaseTransport> transports,
    required bool isSampled,
  }) {
    if (_instance != null) {
      return _instance!;
    }

    final BatchTransport instance;
    if (isSampled) {
      instance = BatchTransport(
        payload: initialPayload,
        batchConfig: batchConfig,
        transports: transports,
      );
    } else {
      instance = NoOpBatchTransport();
    }

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
