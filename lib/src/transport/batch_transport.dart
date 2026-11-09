// ignore_for_file: use_setters_to_change_properties

import 'dart:async';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/device_info/dynamic_device_state_provider.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/no_op_batch_transport.dart';
import 'package:faro/src/util/payload_extension.dart';
import 'package:flutter/foundation.dart';

typedef BatchTransportResolver = BatchTransport? Function();

/// Runtime transport provider, overridden during [Faro.init].
final batchTransportProvider = Provider<BatchTransport?>((pod) => null);

final batchTransportResolverProvider = Provider<BatchTransportResolver>((pod) {
  return () {
    return pod.resolve(batchTransportProvider);
  };
});

/// Transport that batches telemetry data and sends it periodically.
class BatchTransport {
  BatchTransport({
    required Payload payload,
    required BatchConfig batchConfig,
    required List<BaseTransport> transports,
    DynamicDeviceStateProvider? dynamicDeviceState,
  }) : _payload = payload,
       _batchConfig = batchConfig,
       _transports = transports,
       _dynamicDeviceState = dynamicDeviceState {
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
  final DynamicDeviceStateProvider? _dynamicDeviceState;
  Timer? _flushTimer;

  /// The dynamic values that were current when the items of the open payload
  /// were captured. Every item in the payload shares them.
  DynamicDeviceState? _payloadState;

  void addEvent(Event event, {DynamicDeviceStateCapture? capture}) {
    _applyCapture(capture);
    _payload.events.add(event);
    checkPayloadItemLimit();
  }

  void addMeasurement(
    Measurement measurement, {
    DynamicDeviceStateCapture? capture,
  }) {
    _applyCapture(capture);
    _payload.measurements.add(measurement);
    checkPayloadItemLimit();
  }

  void addLog(FaroLog faroLog, {DynamicDeviceStateCapture? capture}) {
    _applyCapture(capture);
    _payload.logs.add(faroLog);
    checkPayloadItemLimit();
  }

  void addSpan(SpanRecord spanRecord, {DynamicDeviceStateCapture? capture}) {
    _applyCapture(capture);
    _payload.traces.addSpan(spanRecord);
    checkPayloadItemLimit();
  }

  void addExceptions(
    FaroException exception, {
    DynamicDeviceStateCapture? capture,
  }) {
    _applyCapture(capture);
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
    _addDynamicDeviceState(payloadJson);

    if (_transports.isNotEmpty) {
      final currentTransports = _transports;
      for (final transport in currentTransports) {
        await transport.send(payloadJson);
      }
    }
  }

  /// Reads the dynamic values now. Reads memory only, so it never waits.
  ///
  /// A caller that holds an item back, such as a user action, takes this when
  /// the item is captured and hands it to the `add` method later. Returns null
  /// when this transport collects no dynamic values.
  DynamicDeviceStateCapture? captureDynamicDeviceState() {
    final provider = _dynamicDeviceState;
    if (provider == null) {
      return null;
    }
    provider.refreshIfStale();
    return DynamicDeviceStateCapture(provider.current);
  }

  /// Applies the values captured with the item that is about to be added. An
  /// item without a [capture] takes the values current now.
  ///
  /// A payload has one `meta`, so a value that changed since the open payload
  /// began closes that payload. The new item then starts a payload of its own.
  /// Each payload then carries the values current when its items were captured.
  void _applyCapture(DynamicDeviceStateCapture? capture) {
    if (_dynamicDeviceState == null) {
      return;
    }
    final state = (capture ?? captureDynamicDeviceState())?.state;
    if (DynamicDeviceState.hasSameValues(state, _payloadState)) {
      return;
    }
    if (payloadSize() > 0) {
      flush(_payload);
      resetPayload();
    }
    _payloadState = state;
  }

  /// Adds the values captured with the payload to its meta.
  ///
  /// A payload without a fresh value goes out without the field. The shared
  /// [Meta] stays untouched, so crash recovery never copies these values.
  void _addDynamicDeviceState(Map<String, dynamic> payloadJson) {
    final state = _payloadState;
    final meta = payloadJson['meta'];
    if (state == null || meta is! Map<String, dynamic>) {
      return;
    }
    final deviceJson = state.device.toJson();
    if (deviceJson.isNotEmpty) {
      final existing = meta['device'];
      meta['device'] = {
        if (existing is Map<String, dynamic>) ...existing,
        ...deviceJson,
      };
    }
    final networkJson = state.network.toJson();
    if (networkJson.isNotEmpty) {
      meta['network'] = networkJson;
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
    DynamicDeviceStateProvider? dynamicDeviceState,
  }) {
    if (_instance != null) {
      return _instance!;
    }

    return _instance = _build(
      initialPayload: initialPayload,
      batchConfig: batchConfig,
      transports: transports,
      isSampled: isSampled,
      dynamicDeviceState: dynamicDeviceState,
    );
  }

  /// Replaces the active transport for a new sampling decision.
  ///
  /// The caller must flush or discard any pending payload before replacing the
  /// transport. The previous transport is disposed so its timer cannot keep
  /// sending after the session boundary.
  BatchTransport replace({
    required Payload initialPayload,
    required BatchConfig batchConfig,
    required List<BaseTransport> transports,
    required bool isSampled,
    DynamicDeviceStateProvider? dynamicDeviceState,
  }) {
    _instance?.dispose();
    return _instance = _build(
      initialPayload: initialPayload,
      batchConfig: batchConfig,
      transports: transports,
      isSampled: isSampled,
      dynamicDeviceState: dynamicDeviceState,
    );
  }

  BatchTransport _build({
    required Payload initialPayload,
    required BatchConfig batchConfig,
    required List<BaseTransport> transports,
    required bool isSampled,
    DynamicDeviceStateProvider? dynamicDeviceState,
  }) {
    final BatchTransport instance;
    if (isSampled) {
      instance = BatchTransport(
        payload: initialPayload,
        batchConfig: batchConfig,
        transports: transports,
        dynamicDeviceState: dynamicDeviceState,
      );
    } else {
      instance = NoOpBatchTransport();
    }

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
