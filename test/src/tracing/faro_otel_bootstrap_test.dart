// ignore_for_file: lines_longer_than_80_chars

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/tracing/faro_otel_bootstrap.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/faro_user_action_span_processor.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _RecordingRouter implements TelemetryRouter {
  final List<TelemetryItem> ingested = [];

  @override
  void ingest(TelemetryItem item, {bool skipBuffer = false}) {
    ingested.add(item);
  }
}

void main() {
  late _RecordingRouter router;

  setUpAll(() {
    registerFallbackValue(TelemetryItem.fromEvent(Event('fallback')));
  });

  setUp(() {
    router = _RecordingRouter();
    pod.overrideProvider<TelemetryRouter>(
      telemetryRouterProvider,
      (_) => router,
    );
    // Bounce the cached span processor so each test gets a fresh exporter.
    pod.overrideProvider<otel.SpanProcessor>(
      faroSpanProcessorProvider,
      (_) => throw StateError('placeholder'),
    );
    pod.removeOverride(faroSpanProcessorProvider);
  });

  tearDown(() async {
    await FaroOtelBootstrap.resetForTesting();
    pod.removeOverride(telemetryRouterProvider);
  });

  group('FaroOtelBootstrap:', () {
    test('initialize is idempotent — second call is a no-op that does not '
        'hang and leaves a working tracer', () async {
      // Regression test: the original implementation called OTel.reset()
      // followed by OTel.initialize() on every subsequent call, which hung
      // under Flutter's fake-async test environment when the bootstrap was
      // re-invoked between testWidgets test cases.
      await FaroOtelBootstrap.initialize();
      // Second call must complete promptly without resetting OTel.
      await FaroOtelBootstrap.initialize().timeout(const Duration(seconds: 5));

      final tracer = FaroTracerFactory().create();
      final span = tracer.startSpanManual('after-double-init');
      span.end();
      await Future<void>.delayed(Duration.zero);

      expect(
        router.ingested.any((i) => i.type == TelemetryItemType.span),
        isTrue,
        reason: 'second initialize() should leave a working tracer pipeline',
      );
    });

    test('resetForTesting tears down the OTel SDK so a subsequent '
        'initialize re-creates the pipeline cleanly', () async {
      await FaroOtelBootstrap.initialize();
      await FaroOtelBootstrap.resetForTesting();

      // setUp re-installs the recording router; force a fresh span processor.
      router.ingested.clear();
      pod.overrideProvider<TelemetryRouter>(
        telemetryRouterProvider,
        (_) => router,
      );
      pod.overrideProvider<otel.SpanProcessor>(
        faroSpanProcessorProvider,
        (_) => throw StateError('placeholder'),
      );
      pod.removeOverride(faroSpanProcessorProvider);

      await FaroOtelBootstrap.initialize();
      final tracer = FaroTracerFactory().create();
      final span = tracer.startSpanManual('after-reset');
      span.end();
      await Future<void>.delayed(Duration.zero);

      expect(
        router.ingested.any((i) => i.type == TelemetryItemType.span),
        isTrue,
      );
    });
  });
}
