import 'package:faro/src/models/models.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class MockTelemetryRouter extends Mock implements TelemetryRouter {}

class FakeReadOnlySpan extends Fake implements otel_sdk.ReadOnlySpan {
  FakeReadOnlySpan({
    required this.name,
    required this.attributes,
    this.kind = otel_api.SpanKind.client,
  });

  @override
  final String name;

  @override
  final otel_sdk.Attributes attributes;

  @override
  final otel_api.SpanKind kind;

  @override
  otel_api.SpanContext get spanContext => otel_api.SpanContext(
    otel_api.TraceId.fromString('00000000000000000000000000000001'),
    otel_api.SpanId.fromString('0000000000000001'),
    otel_api.TraceFlags.sampled,
    otel_api.TraceState.empty(),
  );

  @override
  otel_api.SpanId get parentSpanId => otel_api.SpanId.invalid();

  @override
  Int64 get startTime => Int64(1000000);

  @override
  Int64? get endTime => Int64(2000000);

  @override
  otel_api.SpanStatus get status =>
      otel_api.SpanStatus()..code = otel_api.StatusCode.ok;

  @override
  List<otel_api.SpanEvent> get events => [];

  @override
  int get droppedEventsCount => 0;

  @override
  List<otel_api.SpanLink> get links => [];

  @override
  otel_sdk.InstrumentationScope get instrumentationScope =>
      otel_sdk.InstrumentationScope('test', 'test', '', []);

  @override
  otel_sdk.Resource get resource => otel_sdk.Resource([]);
}

void main() {
  late MockTelemetryRouter mockRouter;

  setUpAll(() {
    registerFallbackValue(TelemetryItem.fromEvent(Event('fallback')));
    registerFallbackValue(false);
  });

  setUp(() {
    mockRouter = MockTelemetryRouter();
  });

  group('FaroExporter:', () {
    group('user action attribute mapping:', () {
      test('should set Event.action and strip attributes '
          'when both faro.action.user.name and faro.action.user.parentId '
          'are present', () {
        final attrs = otel_sdk.Attributes.empty();
        attrs.add(otel_api.Attribute.fromString('http.method', 'GET'));
        attrs.add(otel_api.Attribute.fromString('http.scheme', 'https'));
        attrs.add(
          otel_api.Attribute.fromString('faro.action.user.name', 'checkout'),
        );
        attrs.add(
          otel_api.Attribute.fromString('faro.action.user.parentId', 'abc123'),
        );

        final span = FakeReadOnlySpan(name: 'HTTP GET', attributes: attrs);

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        exporter.export([span]);

        final captured =
            verify(
              () => mockRouter.ingest(
                captureAny(),
                skipBuffer: any(named: 'skipBuffer'),
              ),
            ).captured;

        // captureAny captures positional args only
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
          'is present (missing parentId)', () {
        final attrs = otel_sdk.Attributes.empty();
        attrs.add(otel_api.Attribute.fromString('http.method', 'GET'));
        attrs.add(
          otel_api.Attribute.fromString('faro.action.user.name', 'checkout'),
        );

        final span = FakeReadOnlySpan(name: 'HTTP GET', attributes: attrs);

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        exporter.export([span]);

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
          'are present', () {
        final attrs = otel_sdk.Attributes.empty();
        attrs.add(otel_api.Attribute.fromString('http.method', 'POST'));

        final span = FakeReadOnlySpan(name: 'HTTP POST', attributes: attrs);

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        exporter.export([span]);

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
      test('should ingest span-derived event with skipBuffer: true', () {
        final attrs = otel_sdk.Attributes.empty();
        attrs.add(otel_api.Attribute.fromString('http.method', 'GET'));
        attrs.add(otel_api.Attribute.fromString('http.scheme', 'https'));

        final span = FakeReadOnlySpan(name: 'HTTP GET', attributes: attrs);

        final exporter = FaroExporter(telemetryRouter: mockRouter);
        exporter.export([span]);

        // Event should be ingested with skipBuffer: true
        verify(() => mockRouter.ingest(any(), skipBuffer: true)).called(1);

        // Span should be ingested with default skipBuffer (false)
        verify(() => mockRouter.ingest(any())).called(1);
      });
    });
  });
}
