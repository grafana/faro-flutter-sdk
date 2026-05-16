// ignore_for_file: lines_longer_than_80_chars

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/faro_zone_span_manager.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/tracing/span_exception_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOtelTracer extends Mock implements otel.Tracer {}

class MockFaroZoneSpanManager extends Mock implements FaroZoneSpanManager {}

class MockSessionIdProvider extends Mock implements SessionIdProvider {}

class MockApiSpan extends Mock implements otel.Span {}

class MockSpan extends Mock implements Span {}

class FakeOtelContext extends Fake implements otel.Context {}

class FakeSpan extends Fake implements Span {}

class FakeAttributes extends Fake implements otel.Attributes {}

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
  setUpAll(() async {
    await otel.OTel.initialize(
      serviceName: 'test-service',
      spanProcessor: _NoOpProcessor(),
      detectPlatformResources: false,
      enableMetrics: false,
      enableLogs: false,
    );

    registerFallbackValue(FakeOtelContext());
    registerFallbackValue(otel.SpanKind.client);
    registerFallbackValue(FakeSpan());
    registerFallbackValue(ContextScope.callback);
    registerFallbackValue(FakeAttributes());
  });

  tearDownAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    await otel.OTel.reset();
  });

  group('FaroTracer:', () {
    late FaroTracer faroTracer;
    late MockOtelTracer mockOtelTracer;
    late MockFaroZoneSpanManager mockFaroZoneSpanManager;
    late MockSessionIdProvider mockSessionIdProvider;
    late MockApiSpan mockOtelSpan;

    setUp(() {
      mockOtelTracer = MockOtelTracer();
      mockFaroZoneSpanManager = MockFaroZoneSpanManager();
      mockSessionIdProvider = MockSessionIdProvider();
      mockOtelSpan = MockApiSpan();

      faroTracer = FaroTracer(
        otelTracer: mockOtelTracer,
        faroZoneSpanManager: mockFaroZoneSpanManager,
        sessionIdProvider: mockSessionIdProvider,
      );

      when(() => mockSessionIdProvider.sessionId).thenReturn('test-session-id');
    });

    Map<String, Object> capturedAttributesAsMap(otel.Attributes attrs) {
      return {for (final attr in attrs.toList()) attr.key: attr.value};
    }

    void stubStartSpan() {
      when(
        () => mockOtelTracer.startSpan(
          any(),
          context: any(named: 'context'),
          spanContext: any(named: 'spanContext'),
          parentSpan: any(named: 'parentSpan'),
          kind: any(named: 'kind'),
          attributes: any(named: 'attributes'),
          links: any(named: 'links'),
          isRecording: any(named: 'isRecording'),
        ),
      ).thenReturn(mockOtelSpan);
    }

    group('startSpan:', () {
      test('should create span with correct name and execute body', () async {
        const spanName = 'test-span';
        var bodyExecuted = false;
        Span? receivedSpan;

        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: any(named: 'exceptionOptions'),
          ),
        ).thenAnswer((invocation) async {
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        final result = await faroTracer.startSpan<String>(spanName, (span) {
          bodyExecuted = true;
          receivedSpan = span;
          return 'test-result';
        });

        expect(result, equals('test-result'));
        expect(bodyExecuted, isTrue);
        expect(receivedSpan, isA<InternalSpan>());

        verify(
          () => mockOtelTracer.startSpan(
            spanName,
            context: any(named: 'context'),
            kind: otel.SpanKind.client,
            attributes: any(named: 'attributes'),
          ),
        ).called(1);
        verify(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: any(named: 'exceptionOptions'),
          ),
        ).called(1);
      });

      test('should set session attributes on span', () async {
        const spanName = 'test-span';
        const sessionId = 'session-123';

        when(() => mockSessionIdProvider.sessionId).thenReturn(sessionId);
        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: any(named: 'exceptionOptions'),
          ),
        ).thenAnswer((invocation) async {
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        await faroTracer.startSpan<String>(spanName, (span) => 'result');

        final captured =
            verify(
              () => mockOtelTracer.startSpan(
                spanName,
                context: any(named: 'context'),
                kind: otel.SpanKind.client,
                attributes: captureAny(named: 'attributes'),
              ),
            ).captured;
        final attrs = captured.single as otel.Attributes;
        final attributeMap = capturedAttributesAsMap(attrs);
        expect(attributeMap['session_id'], sessionId);
        expect(attributeMap['session.id'], sessionId);
      });

      test(
        'should include custom attributes along with session attributes',
        () async {
          const spanName = 'test-span';
          const customAttributes = {
            'custom.key1': 'value1',
            'custom.key2': 'value2',
          };

          stubStartSpan();
          when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
          when(
            () => mockFaroZoneSpanManager.executeWithSpan<String>(
              any(),
              any(),
              contextScope: any(named: 'contextScope'),
              exceptionOptions: any(named: 'exceptionOptions'),
            ),
          ).thenAnswer((invocation) async {
            final body = invocation.positionalArguments[1] as Function;
            final span = invocation.positionalArguments[0] as Span;
            return await body(span);
          });

          await faroTracer.startSpan<String>(
            spanName,
            (span) => 'result',
            attributes: customAttributes,
          );

          final captured =
              verify(
                () => mockOtelTracer.startSpan(
                  spanName,
                  context: any(named: 'context'),
                  kind: otel.SpanKind.client,
                  attributes: captureAny(named: 'attributes'),
                ),
              ).captured;
          final attrs = captured.single as otel.Attributes;
          final attributeMap = capturedAttributesAsMap(attrs);
          expect(attributeMap['custom.key1'], 'value1');
          expect(attributeMap['custom.key2'], 'value2');
          expect(attributeMap['session_id'], 'test-session-id');
          expect(attributeMap['session.id'], 'test-session-id');
        },
      );

      test('should thread exceptionOptions to executeWithSpan', () async {
        const spanName = 'test-span';
        const options = SpanExceptionOptions(recordException: false);

        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: any(named: 'exceptionOptions'),
          ),
        ).thenAnswer((invocation) async {
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        await faroTracer.startSpan<String>(
          spanName,
          (span) => 'result',
          exceptionOptions: options,
        );

        verify(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: options,
          ),
        ).called(1);
      });

      test('should pass null exceptionOptions by default', () async {
        const spanName = 'test-span';

        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: any(named: 'exceptionOptions'),
          ),
        ).thenAnswer((invocation) async {
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        await faroTracer.startSpan<String>(spanName, (span) => 'result');

        final captured =
            verify(
              () => mockFaroZoneSpanManager.executeWithSpan<String>(
                any(),
                any(),
                contextScope: any(named: 'contextScope'),
                exceptionOptions: captureAny(named: 'exceptionOptions'),
              ),
            ).captured;
        expect(captured.single, isNull);
      });
    });

    group('startSpanManual:', () {
      test('should create and return span without executing body', () {
        const spanName = 'manual-span';

        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        final result = faroTracer.startSpanManual(spanName);

        expect(result, isA<InternalSpan>());
        verify(
          () => mockOtelTracer.startSpan(
            spanName,
            context: any(named: 'context'),
            kind: otel.SpanKind.client,
            attributes: any(named: 'attributes'),
          ),
        ).called(1);

        verifyNever(
          () => mockFaroZoneSpanManager.executeWithSpan<dynamic>(any(), any()),
        );
      });

      test('should set attributes on manual span', () {
        const spanName = 'manual-span';
        const customAttributes = {'manual.key': 'manual.value'};

        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        faroTracer.startSpanManual(spanName, attributes: customAttributes);

        final captured =
            verify(
              () => mockOtelTracer.startSpan(
                spanName,
                context: any(named: 'context'),
                kind: otel.SpanKind.client,
                attributes: captureAny(named: 'attributes'),
              ),
            ).captured;
        final attrs = captured.single as otel.Attributes;
        final attributeMap = capturedAttributesAsMap(attrs);
        expect(attributeMap['manual.key'], 'manual.value');
        expect(attributeMap['session_id'], 'test-session-id');
        expect(attributeMap['session.id'], 'test-session-id');
      });
    });

    group('getActiveSpan:', () {
      test('should return active span from zone span manager', () {
        final mockActiveSpan = MockSpan();
        when(
          () => mockFaroZoneSpanManager.getActiveSpan(),
        ).thenReturn(mockActiveSpan);

        final result = faroTracer.getActiveSpan();

        expect(result, equals(mockActiveSpan));
        verify(() => mockFaroZoneSpanManager.getActiveSpan()).called(1);
      });

      test('should return null when no active span', () {
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        final result = faroTracer.getActiveSpan();

        expect(result, isNull);
        verify(() => mockFaroZoneSpanManager.getActiveSpan()).called(1);
      });
    });

    group('session integration:', () {
      test(
        'should always include both session_id and session.id attributes',
        () {
          const spanName = 'session-test';
          const sessionId = 'unique-session-xyz';

          when(() => mockSessionIdProvider.sessionId).thenReturn(sessionId);
          stubStartSpan();
          when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

          faroTracer.startSpanManual(spanName);

          final captured =
              verify(
                () => mockOtelTracer.startSpan(
                  spanName,
                  context: any(named: 'context'),
                  kind: otel.SpanKind.client,
                  attributes: captureAny(named: 'attributes'),
                ),
              ).captured;
          final attrs = captured.single as otel.Attributes;
          final attributeMap = capturedAttributesAsMap(attrs);
          expect(attributeMap['session_id'], sessionId);
          expect(attributeMap['session.id'], sessionId);
        },
      );
    });

    group('contextScope:', () {
      test('should pass ContextScope.callback by default', () async {
        const spanName = 'scoped-span';
        ContextScope? capturedScope;

        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: any(named: 'exceptionOptions'),
          ),
        ).thenAnswer((invocation) async {
          capturedScope =
              invocation.namedArguments[#contextScope] as ContextScope?;
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        await faroTracer.startSpan<String>(spanName, (span) => 'result');

        expect(capturedScope, equals(ContextScope.callback));
      });

      test('should pass ContextScope.zone when specified', () async {
        const spanName = 'zone-scoped-span';
        ContextScope? capturedScope;

        stubStartSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(
          () => mockFaroZoneSpanManager.executeWithSpan<String>(
            any(),
            any(),
            contextScope: any(named: 'contextScope'),
            exceptionOptions: any(named: 'exceptionOptions'),
          ),
        ).thenAnswer((invocation) async {
          capturedScope =
              invocation.namedArguments[#contextScope] as ContextScope?;
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        await faroTracer.startSpan<String>(
          spanName,
          (span) => 'result',
          contextScope: ContextScope.zone,
        );

        expect(capturedScope, equals(ContextScope.zone));
      });
    });

    group('Span.noParent:', () {
      test(
        'should create span without parent when Span.noParent is passed',
        () {
          const spanName = 'no-parent-span';
          final mockActiveSpan = MockSpan();

          stubStartSpan();
          when(
            () => mockFaroZoneSpanManager.getActiveSpan(),
          ).thenReturn(mockActiveSpan);

          faroTracer.startSpanManual(spanName, parentSpan: Span.noParent);

          verifyNever(() => mockFaroZoneSpanManager.getActiveSpan());

          verify(
            () => mockOtelTracer.startSpan(
              spanName,
              context: any(named: 'context'),
              kind: otel.SpanKind.client,
              attributes: any(named: 'attributes'),
            ),
          ).called(1);
        },
      );

      test('should ignore active span when Span.noParent is passed even if '
          'active span exists', () {
        const spanName = 'independent-trace';
        final mockActiveSpan = MockSpan();

        stubStartSpan();
        when(
          () => mockFaroZoneSpanManager.getActiveSpan(),
        ).thenReturn(mockActiveSpan);

        final span = faroTracer.startSpanManual(
          spanName,
          parentSpan: Span.noParent,
        );

        expect(span, isA<InternalSpan>());
        verifyNever(() => mockFaroZoneSpanManager.getActiveSpan());
      });

      test(
        'should use active span when parentSpan is null (default behavior)',
        () {
          const spanName = 'child-span';

          stubStartSpan();
          when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

          faroTracer.startSpanManual(spanName);

          verify(() => mockFaroZoneSpanManager.getActiveSpan()).called(1);
        },
      );
    });
  });

  group('FaroTracerFactory:', () {
    setUp(FaroTracerFactory.reset);
    tearDown(FaroTracerFactory.reset);

    test('create() returns a working tracer even when OTel has not been '
        'initialized (e.g. when Faro.init has not run)', () {
      // Regression test: callers like FaroHttpTrackingClient call
      // Faro().startSpanManual without first calling Faro().init(),
      // e.g. in their own unit tests. The factory must degrade to a
      // no-op API tracer rather than throwing a cast error from
      // OTel.tracerProvider.
      // Note: this test relies on no other test having called
      // FaroOtelBootstrap.initialize without a matching reset.
      final tracer = FaroTracerFactory().create();
      final span = tracer.startSpanManual('preinit-span');
      expect(span, isNotNull);
      expect(span.traceId, isNotEmpty);
      span.end();
    });
  });
}
