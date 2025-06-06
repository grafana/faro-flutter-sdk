import 'package:faro/src/models/span_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class MockReadOnlySpan extends Mock implements otel_sdk.ReadOnlySpan {}

class MockAttributes extends Mock implements otel_sdk.Attributes {}

void main() {
  group('SpanRecord:', () {
    group('getFaroEventName:', () {
      test('returns "faro.tracing.fetch" for HTTP spans with http.scheme', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.name).thenReturn('HTTP GET');
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.get('http.scheme')).thenReturn('https');
        when(() => mockAttributes.get('http.method')).thenReturn(null);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventName();

        // Assert
        expect(result, 'faro.tracing.fetch');
      });

      test('returns "faro.tracing.fetch" for HTTP spans with http.method', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.name).thenReturn('HTTP POST');
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.get('http.scheme')).thenReturn(null);
        when(() => mockAttributes.get('http.method')).thenReturn('POST');

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventName();

        // Assert
        expect(result, 'faro.tracing.fetch');
      });

      test('returns "faro.tracing.fetch" for HTTP spans with both attributes',
          () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.name).thenReturn('HTTP GET');
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.get('http.scheme')).thenReturn('https');
        when(() => mockAttributes.get('http.method')).thenReturn('GET');

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventName();

        // Assert
        expect(result, 'faro.tracing.fetch');
      });

      test('returns "span.{name}" for non-HTTP spans', () {
        // Arrange
        const spanName = 'database-query';
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.name).thenReturn(spanName);
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.get('http.scheme')).thenReturn(null);
        when(() => mockAttributes.get('http.method')).thenReturn(null);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventName();

        // Assert
        expect(result, 'span.$spanName');
      });

      test('returns "span.{name}" for spans with empty HTTP attributes', () {
        // Arrange
        const spanName = 'custom-operation';
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.name).thenReturn(spanName);
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.get('http.scheme')).thenReturn('');
        when(() => mockAttributes.get('http.method')).thenReturn('');

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventName();

        // Assert
        expect(result, 'span.$spanName');
      });

      test('handles complex span names correctly', () {
        // Arrange
        const spanName =
            'my-service.complex-operation-with-dashes_and_underscores';
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.name).thenReturn(spanName);
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.get('http.scheme')).thenReturn(null);
        when(() => mockAttributes.get('http.method')).thenReturn(null);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventName();

        // Assert
        expect(result, 'span.$spanName');
      });

      test('handles empty span names correctly', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.name).thenReturn('');
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.get('http.scheme')).thenReturn(null);
        when(() => mockAttributes.get('http.method')).thenReturn(null);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventName();

        // Assert
        expect(result, 'span.');
      });
    });

    group('name:', () {
      test('returns the span name from OpenTelemetry span', () {
        // Arrange
        const expectedName = 'test-span-name';
        final mockSpan = MockReadOnlySpan();
        when(() => mockSpan.name).thenReturn(expectedName);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.name();

        // Assert
        expect(result, expectedName);
      });
    });
  });
}
