// ignore_for_file: lines_longer_than_80_chars

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/log_level.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/tracing/faro_otel_bootstrap.dart';
import 'package:faro/src/tracing/faro_span_context.dart';
import 'package:faro/src/tracing/faro_user_action_span_processor.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every telemetry item handed to the router so tests can inspect the
/// trace context that the public push APIs attached at push time.
class _RecordingRouter implements TelemetryRouter {
  final List<TelemetryItem> ingested = [];

  @override
  void ingest(
    TelemetryItem item, {
    required SessionActivityKind activity,
    bool skipBuffer = false,
  }) {
    ingested.add(item);
  }
}

/// Verifies that logs, events, exceptions, and measurements pushed via the
/// public [Faro] API automatically pick up the currently active span's
/// `trace_id`/`span_id`, mirroring the Faro Web SDK and the OTel logs data
/// model.
void main() {
  late _RecordingRouter router;

  setUp(() async {
    router = _RecordingRouter();
    pod.overrideProvider<TelemetryRouter>(
      telemetryRouterProvider,
      (_) => router,
    );
    // The faroSpanProcessorProvider is a singleton; bounce any stale override
    // so each test builds a fresh processor (see faro_tracing_e2e_test.dart).
    pod.overrideProvider<otel.SpanProcessor>(
      faroSpanProcessorProvider,
      (_) => throw StateError('placeholder — should not be resolved'),
    );
    pod.removeOverride(faroSpanProcessorProvider);
  });

  tearDown(() async {
    await FaroOtelBootstrap.resetForTesting();
    pod.removeOverride(telemetryRouterProvider);
  });

  Map<String, dynamic>? traceOf(TelemetryItemType type) {
    final item = router.ingested.firstWhere((i) => i.type == type);
    switch (type) {
      case TelemetryItemType.log:
        return item.asLog!.trace;
      case TelemetryItemType.event:
        return item.asEvent!.trace;
      case TelemetryItemType.exception:
        return item.asException!.trace;
      case TelemetryItemType.measurement:
        return item.asMeasurement!.trace;
      case TelemetryItemType.span:
        return null;
    }
  }

  group('automatic correlation with the active span', () {
    test('pushLog attaches the active span trace context', () async {
      await FaroOtelBootstrap.initialize();

      late String traceId;
      late String spanId;
      await Faro().startSpan<void>('op.log', (span) async {
        traceId = span.traceId;
        spanId = span.spanId;
        Faro().pushLog('hello', level: LogLevel.info);
      });

      final trace = traceOf(TelemetryItemType.log);
      expect(trace, isNotNull);
      expect(trace!['trace_id'], equals(traceId));
      expect(trace['span_id'], equals(spanId));
    });

    test('pushEvent attaches the active span trace context', () async {
      await FaroOtelBootstrap.initialize();

      late String traceId;
      late String spanId;
      await Faro().startSpan<void>('op.event', (span) async {
        traceId = span.traceId;
        spanId = span.spanId;
        Faro().pushEvent('my_event');
      });

      final trace = traceOf(TelemetryItemType.event);
      expect(trace, isNotNull);
      expect(trace!['trace_id'], equals(traceId));
      expect(trace['span_id'], equals(spanId));
    });

    test('pushError attaches the active span trace context', () async {
      await FaroOtelBootstrap.initialize();

      late String traceId;
      late String spanId;
      await Faro().startSpan<void>('op.error', (span) async {
        traceId = span.traceId;
        spanId = span.spanId;
        Faro().pushError(type: 'TestError', value: 'boom');
      });

      final trace = traceOf(TelemetryItemType.exception);
      expect(trace, isNotNull);
      expect(trace!['trace_id'], equals(traceId));
      expect(trace['span_id'], equals(spanId));
    });

    test('pushMeasurement attaches the active span trace context', () async {
      await FaroOtelBootstrap.initialize();

      late String traceId;
      late String spanId;
      await Faro().startSpan<void>('op.measurement', (span) async {
        traceId = span.traceId;
        spanId = span.spanId;
        Faro().pushMeasurement({'value': 1}, 'custom');
      });

      final trace = traceOf(TelemetryItemType.measurement);
      expect(trace, isNotNull);
      expect(trace!['trace_id'], equals(traceId));
      expect(trace['span_id'], equals(spanId));
    });
  });

  group('no active span', () {
    test('signals pushed outside any span carry no trace context', () async {
      await FaroOtelBootstrap.initialize();

      Faro().pushLog('no-span', level: LogLevel.info);
      Faro().pushEvent('no_span_event');
      Faro().pushError(type: 'TestError', value: 'boom');
      Faro().pushMeasurement({'value': 1}, 'custom');

      expect(traceOf(TelemetryItemType.log), isNull);
      expect(traceOf(TelemetryItemType.event), isNull);
      expect(traceOf(TelemetryItemType.exception), isNull);
      expect(traceOf(TelemetryItemType.measurement), isNull);
    });

    test('empty trace is omitted from serialized JSON', () async {
      await FaroOtelBootstrap.initialize();

      Faro().pushLog('no-span', level: LogLevel.info);
      Faro().pushEvent('no_span_event');
      Faro().pushError(type: 'TestError', value: 'boom');
      Faro().pushMeasurement({'value': 1}, 'custom');

      final logJson = router.ingested
          .firstWhere((i) => i.type == TelemetryItemType.log)
          .asLog!
          .toJson();
      final eventJson = router.ingested
          .firstWhere((i) => i.type == TelemetryItemType.event)
          .asEvent!
          .toJson();
      final exceptionJson = router.ingested
          .firstWhere((i) => i.type == TelemetryItemType.exception)
          .asException!
          .toJson();
      final measurementJson = router.ingested
          .firstWhere((i) => i.type == TelemetryItemType.measurement)
          .asMeasurement!
          .toJson();

      expect(logJson.containsKey('trace'), isFalse);
      expect(eventJson.containsKey('trace'), isFalse);
      expect(exceptionJson.containsKey('trace'), isFalse);
      expect(measurementJson.containsKey('trace'), isFalse);
    });
  });

  group('manual override precedence', () {
    test('explicit trace wins over the active span', () async {
      await FaroOtelBootstrap.initialize();

      const override = FaroSpanContext(
        traceId: 'manual-trace',
        spanId: 'manual-span',
      );
      final expectedTrace = override.toJson();
      await Faro().startSpan<void>('op.override', (span) async {
        expect(span.traceId, isNot(equals('manual-trace')));
        Faro().pushLog(
          'overridden',
          level: LogLevel.info,
          spanContext: override,
        );
        Faro().pushEvent('overridden_event', spanContext: override);
        Faro().pushError(
          type: 'TestError',
          value: 'boom',
          spanContext: override,
        );
        Faro().pushMeasurement({'value': 1}, 'custom', spanContext: override);
      });

      expect(traceOf(TelemetryItemType.log), equals(expectedTrace));
      expect(traceOf(TelemetryItemType.event), equals(expectedTrace));
      expect(traceOf(TelemetryItemType.exception), equals(expectedTrace));
      expect(traceOf(TelemetryItemType.measurement), equals(expectedTrace));
    });
  });

  group('capture at push time', () {
    test('trace attached at push time survives after the span ends', () async {
      await FaroOtelBootstrap.initialize();

      late String traceId;
      late String spanId;
      await Faro().startSpan<void>('op.capture', (span) async {
        traceId = span.traceId;
        spanId = span.spanId;
        Faro().pushLog('captured', level: LogLevel.info);
      });

      // The span has ended by now; the trace must have been captured on the
      // model synchronously at push time (before any later flush/enrichment).
      final trace = traceOf(TelemetryItemType.log);
      expect(trace, isNotNull);
      expect(trace!['trace_id'], equals(traceId));
      expect(trace['span_id'], equals(spanId));
    });
  });
}
