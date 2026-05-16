// ignore_for_file: lines_longer_than_80_chars

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/tracing/faro_otel_bootstrap.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/faro_user_action_span_processor.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _RecordingRouter implements TelemetryRouter {
  final List<TelemetryItem> ingested = [];
  final List<bool> skipBufferFlags = [];

  @override
  void ingest(TelemetryItem item, {bool skipBuffer = false}) {
    ingested.add(item);
    skipBufferFlags.add(skipBuffer);
  }
}

/// End-to-end smoke tests that verify a span created via the public
/// FaroTracer surface flows through dartastic_opentelemetry's
/// SpanProcessor + SpanExporter chain and lands on the Faro
/// [TelemetryRouter] as a span+event pair with the expected attributes.
///
/// This is the most important integration check after the OTel SDK swap:
/// it catches breakage anywhere along the InternalSpan -> APISpan ->
/// SimpleSpanProcessor -> FaroExporter -> TelemetryRouter path.
void main() {
  late _RecordingRouter router;

  setUpAll(() {
    registerFallbackValue(TelemetryItem.fromEvent(Event('fallback')));
  });

  setUp(() async {
    router = _RecordingRouter();
    pod.overrideProvider<TelemetryRouter>(
      telemetryRouterProvider,
      (_) => router,
    );
    // The faroSpanProcessorProvider is a singleton; if a previous test
    // built (and then shut down) one, the cache would hand back a dead
    // processor here. Bounce the override to force fresh construction.
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

  test('Faro.startSpanManual flows through to the telemetry router as '
      'an Event with span attributes and a span TelemetryItem', () async {
    await FaroOtelBootstrap.initialize();
    final tracer = FaroTracerFactory().create();

    final span = tracer.startSpanManual(
      'order.checkout',
      attributes: const {'cart.size': 3, 'cart.currency': 'EUR'},
    );
    span.end();

    // Allow async export to drain.
    await Future<void>.delayed(Duration.zero);

    expect(router.ingested, hasLength(2), reason: 'one Event + one Span');

    final eventItem = router.ingested.firstWhere(
      (i) => i.type == TelemetryItemType.event,
    );
    final event = eventItem.asEvent!;
    expect(event.name, equals('span.order.checkout'));
    expect(event.attributes!['cart.size'], equals('3'));
    expect(event.attributes!['cart.currency'], equals('EUR'));
    expect(event.trace, isNotNull);
    expect(event.trace!['trace_id'], equals(span.traceId));
    expect(event.trace!['span_id'], equals(span.spanId));

    final spanItem = router.ingested.firstWhere(
      (i) => i.type == TelemetryItemType.span,
    );
    expect(spanItem.asSpan, isNotNull);

    // The event is delivered with skipBuffer=true so user-action buffering
    // does not stall span-derived events.
    final eventIndex = router.ingested.indexOf(eventItem);
    expect(router.skipBufferFlags[eventIndex], isTrue);
  });

  test('HTTP-flavored spans surface as faro.tracing.fetch events', () async {
    await FaroOtelBootstrap.initialize();
    final tracer = FaroTracerFactory().create();

    final span = tracer.startSpanManual(
      'GET https://example.com',
      attributes: const {
        'http.method': 'GET',
        'http.scheme': 'https',
        'http.url': 'https://example.com/orders',
      },
    );
    span.end();
    await Future<void>.delayed(Duration.zero);

    final eventItem = router.ingested.firstWhere(
      (i) => i.type == TelemetryItemType.event,
    );
    expect(eventItem.asEvent!.name, equals('faro.tracing.fetch'));
  });

  test('child span shares the parent trace_id', () async {
    await FaroOtelBootstrap.initialize();
    final tracer = FaroTracerFactory().create();

    final parent = tracer.startSpanManual('parent');
    final child = tracer.startSpanManual('child', parentSpan: parent);
    expect(child.traceId, equals(parent.traceId));
    expect(child.spanId, isNot(equals(parent.spanId)));
    child.end();
    parent.end();
  });

  test(
    'Span.noParent starts a new trace even when an active span exists',
    () async {
      await FaroOtelBootstrap.initialize();
      final tracer = FaroTracerFactory().create();

      final outer = tracer.startSpanManual('outer');
      final detached = tracer.startSpanManual(
        'detached',
        parentSpan: Span.noParent,
      );
      expect(detached.traceId, isNot(equals(outer.traceId)));
      detached.end();
      outer.end();
    },
  );
}
