import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/models/models.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTelemetryRouter extends Mock implements TelemetryRouter {}

class _NoOpProcessor implements otel.SpanProcessor {
  @override
  Future<void> onStart(otel.Span span, otel.Context? parentContext) async {}
  @override
  Future<void> onEnd(otel.Span span) async {}
  @override
  Future<void> onNameUpdate(otel.Span span, String newName) async {}
  @override
  Future<void> shutdown() async {}
  @override
  Future<void> forceFlush() async {}
}

void main() {
  late MockTelemetryRouter mockRouter;
  late otel.Tracer tracer;

  setUpAll(() async {
    await otel.OTel.initialize(
      serviceName: 'test-service',
      spanProcessor: _NoOpProcessor(),
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
    );
    tracer = otel.OTel.tracer();
    registerFallbackValue(TelemetryItem.fromEvent(Event('fallback')));
    registerFallbackValue(false);
  });

  tearDownAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    await otel.OTel.reset();
  });

  setUp(() {
    mockRouter = MockTelemetryRouter();
  });

  otel.Span makeSpan(String name, Map<String, Object> attributes) {
    final span = tracer.startSpan(
      name,
      kind: otel.SpanKind.client,
      attributes: otel.OTel.attributesFromMap(attributes),
    );
    span.end();
    return span;
  }

  group('FaroExporter:', () {
    group('user action attribute mapping:', () {
      test('should set Event.action and strip attributes '
          'when both faro.action.user.name and faro.action.user.parentId '
          'are present', () async {
        final span = makeSpan('HTTP GET', {
          'http.method': 'GET',
          'http.scheme': 'https',
          'faro.action.user.name': 'checkout',
          'faro.action.user.parentId': 'abc123',
        });

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        await exporter.export([span]);

        final captured =
            verify(
              () => mockRouter.ingest(
                captureAny(),
                skipBuffer: any(named: 'skipBuffer'),
              ),
            ).captured;

        expect(captured, hasLength(2));

        final eventItem = captured[0] as TelemetryItem;
        expect(eventItem.type, equals(TelemetryItemType.event));

        final event = eventItem.asEvent!;
        expect(event.action, isNotNull);
        expect(event.action!.name, equals('checkout'));
        expect(event.action!.parentId, equals('abc123'));

        expect(event.attributes!.containsKey('faro.action.user.name'), isFalse);
        expect(
          event.attributes!.containsKey('faro.action.user.parentId'),
          isFalse,
        );

        expect(event.attributes!['http.method'], equals('GET'));
        expect(event.attributes!['http.scheme'], equals('https'));
      });

      test('should NOT set Event.action when only faro.action.user.name '
          'is present (missing parentId)', () async {
        final span = makeSpan('HTTP GET', {
          'http.method': 'GET',
          'faro.action.user.name': 'checkout',
        });

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        await exporter.export([span]);

        final captured =
            verify(
              () => mockRouter.ingest(
                captureAny(),
                skipBuffer: any(named: 'skipBuffer'),
              ),
            ).captured;

        final eventItem = captured[0] as TelemetryItem;
        final event = eventItem.asEvent!;
        expect(event.action, isNull);
        expect(event.attributes!.containsKey('faro.action.user.name'), isTrue);
      });

      test('should NOT set Event.action when no action attributes '
          'are present', () async {
        final span = makeSpan('HTTP POST', {'http.method': 'POST'});

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        await exporter.export([span]);

        final captured =
            verify(
              () => mockRouter.ingest(
                captureAny(),
                skipBuffer: any(named: 'skipBuffer'),
              ),
            ).captured;

        final eventItem = captured[0] as TelemetryItem;
        final event = eventItem.asEvent!;
        expect(event.action, isNull);
      });
    });

    group('telemetry routing:', () {
      test('should ingest span-derived event with skipBuffer: true', () async {
        final span = makeSpan('HTTP GET', {
          'http.method': 'GET',
          'http.scheme': 'https',
        });

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        await exporter.export([span]);

        verify(() => mockRouter.ingest(any(), skipBuffer: true)).called(1);
        verify(() => mockRouter.ingest(any())).called(1);
      });
    });
  });
}
