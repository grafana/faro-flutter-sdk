// ignore_for_file: lines_longer_than_80_chars

import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/faro_zone_span_manager.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/api.dart' as otel_api;

class MockOtelTracer extends Mock implements otel_api.Tracer {}

class MockFaroZoneSpanManager extends Mock implements FaroZoneSpanManager {}

class MockSessionIdProvider extends Mock implements SessionIdProvider {}

class MockOtelSpan extends Mock implements otel_api.Span {}

class MockSpan extends Mock implements Span {}

class FakeOtelContext extends Fake implements otel_api.Context {}

class FakeSpan extends Fake implements Span {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeOtelContext());
    registerFallbackValue(otel_api.SpanKind.client);
    registerFallbackValue(FakeSpan());
  });
  group('FaroTracer:', () {
    late FaroTracer faroTracer;
    late MockOtelTracer mockOtelTracer;
    late MockFaroZoneSpanManager mockFaroZoneSpanManager;
    late MockSessionIdProvider mockSessionIdProvider;
    late MockOtelSpan mockOtelSpan;

    setUp(() {
      mockOtelTracer = MockOtelTracer();
      mockFaroZoneSpanManager = MockFaroZoneSpanManager();
      mockSessionIdProvider = MockSessionIdProvider();
      mockOtelSpan = MockOtelSpan();

      // Create FaroTracer with public constructor
      faroTracer = FaroTracer(
        otelTracer: mockOtelTracer,
        faroZoneSpanManager: mockFaroZoneSpanManager,
        sessionIdProvider: mockSessionIdProvider,
      );

      // Set up default mock behaviors
      when(() => mockSessionIdProvider.sessionId).thenReturn('test-session-id');
    });

    group('startSpan:', () {
      test('should create span with correct name and execute body', () async {
        // Arrange
        const spanName = 'test-span';
        var bodyExecuted = false;
        Span? receivedSpan;

        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);

        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(() => mockFaroZoneSpanManager.executeWithSpan<String>(
              any(),
              any(),
            )).thenAnswer((invocation) async {
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        // Act
        final result = await faroTracer.startSpan<String>(spanName, (span) {
          bodyExecuted = true;
          receivedSpan = span;
          return 'test-result';
        });

        // Assert
        expect(result, equals('test-result'));
        expect(bodyExecuted, isTrue);
        expect(receivedSpan, isA<InternalSpan>());

        verify(() => mockOtelTracer.startSpan(
              spanName,
              context: any(named: 'context'),
              kind: otel_api.SpanKind.client,
            )).called(1);
        verify(() => mockFaroZoneSpanManager.executeWithSpan<String>(
              any(),
              any(),
            )).called(1);
      });

      test('should set session attributes on span', () async {
        // Arrange
        const spanName = 'test-span';
        const sessionId = 'session-123';

        when(() => mockSessionIdProvider.sessionId).thenReturn(sessionId);
        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(() => mockFaroZoneSpanManager.executeWithSpan<String>(
              any(),
              any(),
            )).thenAnswer((invocation) async {
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        // Act
        await faroTracer.startSpan<String>(spanName, (span) => 'result');

        // Assert
        verify(() => mockOtelSpan.setAttributes(
              any(that: predicate<List<otel_api.Attribute>>((attributes) {
                final attributeMap = <String, String>{
                  for (final attr in attributes) attr.key: attr.value.toString()
                };
                return attributeMap['session_id'] == sessionId &&
                    attributeMap['session.id'] == sessionId;
              })),
            )).called(1);
      });

      test('should include custom attributes along with session attributes',
          () async {
        // Arrange
        const spanName = 'test-span';
        const customAttributes = {
          'custom.key1': 'value1',
          'custom.key2': 'value2',
        };

        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);
        when(() => mockFaroZoneSpanManager.executeWithSpan<String>(
              any(),
              any(),
            )).thenAnswer((invocation) async {
          final body = invocation.positionalArguments[1] as Function;
          final span = invocation.positionalArguments[0] as Span;
          return await body(span);
        });

        // Act
        await faroTracer.startSpan<String>(
          spanName,
          (span) => 'result',
          attributes: customAttributes,
        );

        // Assert
        verify(() => mockOtelSpan.setAttributes(
              any(that: predicate<List<otel_api.Attribute>>((attributes) {
                final attributeMap = <String, String>{
                  for (final attr in attributes) attr.key: attr.value.toString()
                };
                return attributeMap['custom.key1'] == 'value1' &&
                    attributeMap['custom.key2'] == 'value2' &&
                    attributeMap['session_id'] == 'test-session-id' &&
                    attributeMap['session.id'] == 'test-session-id';
              })),
            )).called(1);
      });
    });

    group('startSpanManual:', () {
      test('should create and return span without executing body', () {
        // Arrange
        const spanName = 'manual-span';

        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        // Act
        final result = faroTracer.startSpanManual(spanName);

        // Assert
        expect(result, isA<InternalSpan>());
        verify(() => mockOtelTracer.startSpan(
              spanName,
              context: any(named: 'context'),
              kind: otel_api.SpanKind.client,
            )).called(1);

        // Verify executeWithSpan is NOT called for manual spans
        verifyNever(() => mockFaroZoneSpanManager.executeWithSpan<dynamic>(
              any(),
              any(),
            ));
      });

      test('should set attributes on manual span', () {
        // Arrange
        const spanName = 'manual-span';
        const customAttributes = {
          'manual.key': 'manual.value',
        };

        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        // Act
        faroTracer.startSpanManual(spanName, attributes: customAttributes);

        // Assert
        verify(() => mockOtelSpan.setAttributes(
              any(that: predicate<List<otel_api.Attribute>>((attributes) {
                final attributeMap = <String, String>{
                  for (final attr in attributes) attr.key: attr.value.toString()
                };
                return attributeMap['manual.key'] == 'manual.value' &&
                    attributeMap['session_id'] == 'test-session-id' &&
                    attributeMap['session.id'] == 'test-session-id';
              })),
            )).called(1);
      });
    });

    group('getActiveSpan:', () {
      test('should return active span from zone span manager', () {
        // Arrange
        final mockActiveSpan = MockSpan();
        when(() => mockFaroZoneSpanManager.getActiveSpan())
            .thenReturn(mockActiveSpan);

        // Act
        final result = faroTracer.getActiveSpan();

        // Assert
        expect(result, equals(mockActiveSpan));
        verify(() => mockFaroZoneSpanManager.getActiveSpan()).called(1);
      });

      test('should return null when no active span', () {
        // Arrange
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        // Act
        final result = faroTracer.getActiveSpan();

        // Assert
        expect(result, isNull);
        verify(() => mockFaroZoneSpanManager.getActiveSpan()).called(1);
      });
    });

    group('session integration:', () {
      test('should always include both session_id and session.id attributes',
          () {
        // Arrange
        const spanName = 'session-test';
        const sessionId = 'unique-session-xyz';

        when(() => mockSessionIdProvider.sessionId).thenReturn(sessionId);
        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        // Act
        faroTracer.startSpanManual(spanName);

        // Assert
        verify(() => mockOtelSpan.setAttributes(
              any(that: predicate<List<otel_api.Attribute>>((attributes) {
                final attributeMap = <String, String>{
                  for (final attr in attributes) attr.key: attr.value.toString()
                };
                return attributeMap['session_id'] == sessionId &&
                    attributeMap['session.id'] == sessionId;
              })),
            )).called(1);
      });
    });

    group('Span.noParent:', () {
      test('should create span without parent when Span.noParent is passed',
          () {
        // Arrange
        const spanName = 'no-parent-span';
        final mockActiveSpan = MockSpan();

        when(() => mockSessionIdProvider.sessionId)
            .thenReturn('test-session-id');
        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        when(() => mockFaroZoneSpanManager.getActiveSpan())
            .thenReturn(mockActiveSpan);

        // Act
        faroTracer.startSpanManual(spanName, parentSpan: Span.noParent);

        // Assert - should NOT call getActiveSpan since we're explicitly
        // requesting no parent
        verifyNever(() => mockFaroZoneSpanManager.getActiveSpan());

        // Verify span was created (with default context, not parent's context)
        verify(() => mockOtelTracer.startSpan(
              spanName,
              context: any(named: 'context'),
              kind: otel_api.SpanKind.client,
            )).called(1);
      });

      test(
          'should ignore active span when Span.noParent is passed even if '
          'active span exists', () {
        // Arrange
        const spanName = 'independent-trace';
        final mockActiveSpan = MockSpan();

        when(() => mockSessionIdProvider.sessionId)
            .thenReturn('test-session-id');
        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        // Even though there's an active span available...
        when(() => mockFaroZoneSpanManager.getActiveSpan())
            .thenReturn(mockActiveSpan);

        // Act - pass Span.noParent to explicitly request no parent
        final span =
            faroTracer.startSpanManual(spanName, parentSpan: Span.noParent);

        // Assert
        expect(span, isA<InternalSpan>());
        // getActiveSpan should not be called when Span.noParent is used
        verifyNever(() => mockFaroZoneSpanManager.getActiveSpan());
      });

      test('should use active span when parentSpan is null (default behavior)',
          () {
        // Arrange
        const spanName = 'child-span';

        when(() => mockSessionIdProvider.sessionId)
            .thenReturn('test-session-id');
        when(() => mockOtelTracer.startSpan(
              any(),
              context: any(named: 'context'),
              kind: any(named: 'kind'),
            )).thenReturn(mockOtelSpan);
        when(() => mockFaroZoneSpanManager.getActiveSpan()).thenReturn(null);

        // Act - no parentSpan provided, should check for active span
        faroTracer.startSpanManual(spanName);

        // Assert - should call getActiveSpan to check for parent
        verify(() => mockFaroZoneSpanManager.getActiveSpan()).called(1);
      });
    });
  });
}
