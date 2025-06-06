// ignore_for_file: avoid_redundant_argument_values

import 'package:faro/src/models/span_record.dart';
import 'package:fixnum/fixnum.dart';
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
        when(() => mockSpan.startTime).thenReturn(Int64(0));
        when(() => mockSpan.endTime).thenReturn(null);

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
        when(() => mockSpan.startTime).thenReturn(Int64(0));
        when(() => mockSpan.endTime).thenReturn(null);

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
        when(() => mockSpan.startTime).thenReturn(Int64(0));
        when(() => mockSpan.endTime).thenReturn(null);

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
        when(() => mockSpan.startTime).thenReturn(Int64(0));
        when(() => mockSpan.endTime).thenReturn(null);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result['single_quote'], '"');
      });

      test('includes duration when start and end times are valid', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['test.key']);
        when(() => mockAttributes.get('test.key')).thenReturn('test.value');
        when(() => mockSpan.startTime)
            .thenReturn(Int64(1000000000)); // 1 second in nanoseconds
        when(() => mockSpan.endTime)
            .thenReturn(Int64(2500000000)); // 2.5 seconds in nanoseconds

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(
            result['duration_ns'], '1500000000'); // 1.5 seconds in nanoseconds
        expect(result['test.key'], 'test.value');
      });

      test('does not include duration when start time is invalid', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['test.key']);
        when(() => mockAttributes.get('test.key')).thenReturn('test.value');
        when(() => mockSpan.startTime).thenReturn(Int64(0));
        when(() => mockSpan.endTime).thenReturn(Int64(2500000000));

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result.containsKey('duration_ns'), false);
        expect(result['test.key'], 'test.value');
      });

      test('does not include duration when end time is invalid', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['test.key']);
        when(() => mockAttributes.get('test.key')).thenReturn('test.value');
        when(() => mockSpan.startTime).thenReturn(Int64(1000000000));
        when(() => mockSpan.endTime).thenReturn(null);

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result.containsKey('duration_ns'), false);
        expect(result['test.key'], 'test.value');
      });

      test('does not include duration when both times are invalid', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['test.key']);
        when(() => mockAttributes.get('test.key')).thenReturn('test.value');
        when(() => mockSpan.startTime).thenReturn(Int64(0));
        when(() => mockSpan.endTime).thenReturn(Int64(0));

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result.containsKey('duration_ns'), false);
        expect(result['test.key'], 'test.value');
      });

      test('includes all original attributes plus duration', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['attr1', 'attr2', 'attr3']);
        when(() => mockAttributes.get('attr1')).thenReturn('value1');
        when(() => mockAttributes.get('attr2')).thenReturn(42);
        when(() => mockAttributes.get('attr3')).thenReturn(true);
        when(() => mockSpan.startTime).thenReturn(Int64(1000000000));
        when(() => mockSpan.endTime).thenReturn(Int64(3000000000));

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result['duration_ns'], '2000000000');
        expect(result['attr1'], 'value1');
        expect(result['attr2'], '42');
        expect(result['attr3'], 'true');
        expect(result.length, 4); // 3 original attributes + duration
      });

      test('does not include duration when end time is before start time', () {
        // Arrange
        final mockSpan = MockReadOnlySpan();
        final mockAttributes = MockAttributes();
        when(() => mockSpan.attributes).thenReturn(mockAttributes);
        when(() => mockAttributes.keys).thenReturn(['test.key']);
        when(() => mockAttributes.get('test.key')).thenReturn('test.value');
        when(() => mockSpan.startTime)
            .thenReturn(Int64(2500000000)); // 2.5 seconds
        when(() => mockSpan.endTime)
            .thenReturn(Int64(1000000000)); // 1 second (before start time)

        final spanRecord = SpanRecord(otelReadOnlySpan: mockSpan);

        // Act
        final result = spanRecord.getFaroEventAttributes();

        // Assert
        expect(result.containsKey('duration_ns'), false);
        expect(result['test.key'], 'test.value');
      });
    });
  });
}
