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

    group('getFaroEventAttributes:', () {
      test('sanitizes attribute values by removing surrounding quotes', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['url', 'method', 'status']);
        when(() => mockAttributes.get('url'))
            .thenReturn('"https://example.com"');
        when(() => mockAttributes.get('method')).thenReturn('GET');
        when(() => mockAttributes.get('status')).thenReturn('"200"');

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result['url'], 'https://example.com');
        expect(result['method'], 'GET');
        expect(result['status'], '200');
      });

      test('preserves values without quotes', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['count', 'enabled']);
        when(() => mockAttributes.get('count')).thenReturn('42');
        when(() => mockAttributes.get('enabled')).thenReturn('true');

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result['count'], '42');
        expect(result['enabled'], 'true');
      });

      test('handles empty and null values correctly', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['empty', 'null_value']);
        when(() => mockAttributes.get('empty')).thenReturn('');
        when(() => mockAttributes.get('null_value')).thenReturn(null);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result['empty'], '');
        expect(result['null_value'], 'null');
      });

      test('handles single quote correctly', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['single_quote']);
        when(() => mockAttributes.get('single_quote')).thenReturn('"');

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result['single_quote'], '"');
      });
    });
  });
}
