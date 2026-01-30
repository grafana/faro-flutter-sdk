// ignore_for_file: lines_longer_than_80_chars

import 'package:faro/src/tracing/span.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/api.dart' as otel_api;

class MockOtelSpan extends Mock implements otel_api.Span {}

class FakeOtelContext extends Fake implements otel_api.Context {}

void main() {
  setUpAll(() {
    registerFallbackValue(otel_api.StatusCode.unset);
    registerFallbackValue(<otel_api.Attribute>[]);
    registerFallbackValue(otel_api.Attribute.fromString('key', 'value'));
  });

  group('Span.noParent sentinel:', () {
    test('should be a const singleton', () {
      // Act
      const a = Span.noParent;
      const b = Span.noParent;

      // Assert - both references should be identical (same object)
      expect(identical(a, b), isTrue);
      expect(a == b, isTrue);
    });

    test('should throw UnsupportedError when traceId is accessed', () {
      expect(
        () => Span.noParent.traceId,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when spanId is accessed', () {
      expect(
        () => Span.noParent.spanId,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when wasEnded is accessed', () {
      expect(
        () => Span.noParent.wasEnded,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when status is accessed', () {
      expect(
        () => Span.noParent.status,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when statusHasBeenSet is accessed', () {
      expect(
        () => Span.noParent.statusHasBeenSet,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when setStatus is called', () {
      expect(
        () => Span.noParent.setStatus(SpanStatusCode.ok),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when addEvent is called', () {
      expect(
        () => Span.noParent.addEvent('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when setAttributes is called', () {
      expect(
        () => Span.noParent.setAttributes({'key': 'value'}),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when setAttribute is called', () {
      expect(
        () => Span.noParent.setAttribute('key', 'value'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when recordException is called', () {
      expect(
        () => Span.noParent.recordException(Exception('test')),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should throw UnsupportedError when end is called', () {
      expect(
        () => Span.noParent.end(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('should have descriptive error message', () {
      expect(
        () => Span.noParent.traceId,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Span.noParent'),
              contains('sentinel'),
              contains('parentSpan'),
            ),
          ),
        ),
      );
    });
  });

  group('InternalSpan:', () {
    late MockOtelSpan mockOtelSpan;
    late FakeOtelContext fakeContext;

    setUp(() {
      mockOtelSpan = MockOtelSpan();
      fakeContext = FakeOtelContext();
    });

    Span createSpan() {
      return SpanProvider().getSpan(mockOtelSpan, fakeContext);
    }

    group('setAttributes with typed values:', () {
      test('should pass string attributes to OTel span', () {
        final span = createSpan();
        final capturedAttributes = <otel_api.Attribute>[];

        when(() => mockOtelSpan.setAttributes(any())).thenAnswer((invocation) {
          capturedAttributes.addAll(
              invocation.positionalArguments[0] as List<otel_api.Attribute>);
        });

        span.setAttributes({'name': 'test'});

        expect(capturedAttributes.length, 1);
        expect(capturedAttributes[0].key, 'name');
        expect(capturedAttributes[0].value, 'test');
      });

      test('should pass int attributes to OTel span', () {
        final span = createSpan();
        final capturedAttributes = <otel_api.Attribute>[];

        when(() => mockOtelSpan.setAttributes(any())).thenAnswer((invocation) {
          capturedAttributes.addAll(
              invocation.positionalArguments[0] as List<otel_api.Attribute>);
        });

        span.setAttributes({'count': 42});

        expect(capturedAttributes.length, 1);
        expect(capturedAttributes[0].key, 'count');
        expect(capturedAttributes[0].value, 42);
      });

      test('should pass double attributes to OTel span', () {
        final span = createSpan();
        final capturedAttributes = <otel_api.Attribute>[];

        when(() => mockOtelSpan.setAttributes(any())).thenAnswer((invocation) {
          capturedAttributes.addAll(
              invocation.positionalArguments[0] as List<otel_api.Attribute>);
        });

        span.setAttributes({'score': 99.5});

        expect(capturedAttributes.length, 1);
        expect(capturedAttributes[0].key, 'score');
        expect(capturedAttributes[0].value, 99.5);
      });

      test('should pass bool attributes to OTel span', () {
        final span = createSpan();
        final capturedAttributes = <otel_api.Attribute>[];

        when(() => mockOtelSpan.setAttributes(any())).thenAnswer((invocation) {
          capturedAttributes.addAll(
              invocation.positionalArguments[0] as List<otel_api.Attribute>);
        });

        span.setAttributes({'enabled': true});

        expect(capturedAttributes.length, 1);
        expect(capturedAttributes[0].key, 'enabled');
        expect(capturedAttributes[0].value, true);
      });

      test('should pass mixed type attributes to OTel span', () {
        final span = createSpan();
        final capturedAttributes = <otel_api.Attribute>[];

        when(() => mockOtelSpan.setAttributes(any())).thenAnswer((invocation) {
          capturedAttributes.addAll(
              invocation.positionalArguments[0] as List<otel_api.Attribute>);
        });

        span.setAttributes({
          'name': 'test',
          'count': 42,
          'score': 99.5,
          'enabled': true,
        });

        expect(capturedAttributes.length, 4);

        final attrMap = {
          for (final attr in capturedAttributes) attr.key: attr.value
        };
        expect(attrMap['name'], 'test');
        expect(attrMap['count'], 42);
        expect(attrMap['score'], 99.5);
        expect(attrMap['enabled'], true);
      });
    });

    group('addEvent with typed attributes:', () {
      test('should pass typed attributes to event', () {
        final span = createSpan();
        final capturedAttributes = <otel_api.Attribute>[];

        when(() => mockOtelSpan.addEvent(any(),
            attributes: any(named: 'attributes'))).thenAnswer((invocation) {
          final attrs = invocation.namedArguments[const Symbol('attributes')]
              as List<otel_api.Attribute>?;
          if (attrs != null) {
            capturedAttributes.addAll(attrs);
          }
        });

        span.addEvent('test event', attributes: {
          'message': 'hello',
          'count': 5,
          'duration': 1.5,
          'success': true,
        });

        expect(capturedAttributes.length, 4);

        final attrMap = {
          for (final attr in capturedAttributes) attr.key: attr.value
        };
        expect(attrMap['message'], 'hello');
        expect(attrMap['count'], 5);
        expect(attrMap['duration'], 1.5);
        expect(attrMap['success'], true);
      });
    });

    group('setAttribute with typed value:', () {
      test('should pass string value to OTel span', () {
        final span = createSpan();
        otel_api.Attribute? capturedAttribute;

        when(() => mockOtelSpan.setAttribute(any())).thenAnswer((invocation) {
          capturedAttribute =
              invocation.positionalArguments[0] as otel_api.Attribute;
        });

        span.setAttribute('name', 'test');

        expect(capturedAttribute?.key, 'name');
        expect(capturedAttribute?.value, 'test');
      });

      test('should pass int value to OTel span via setAttribute', () {
        final span = createSpan();
        otel_api.Attribute? capturedAttribute;

        when(() => mockOtelSpan.setAttribute(any())).thenAnswer((invocation) {
          capturedAttribute =
              invocation.positionalArguments[0] as otel_api.Attribute;
        });

        span.setAttribute('count', 42);

        expect(capturedAttribute?.key, 'count');
        expect(capturedAttribute?.value, 42);
      });

      test('should pass double value to OTel span via setAttribute', () {
        final span = createSpan();
        otel_api.Attribute? capturedAttribute;

        when(() => mockOtelSpan.setAttribute(any())).thenAnswer((invocation) {
          capturedAttribute =
              invocation.positionalArguments[0] as otel_api.Attribute;
        });

        span.setAttribute('score', 99.5);

        expect(capturedAttribute?.key, 'score');
        expect(capturedAttribute?.value, 99.5);
      });

      test('should pass bool value to OTel span via setAttribute', () {
        final span = createSpan();
        otel_api.Attribute? capturedAttribute;

        when(() => mockOtelSpan.setAttribute(any())).thenAnswer((invocation) {
          capturedAttribute =
              invocation.positionalArguments[0] as otel_api.Attribute;
        });

        span.setAttribute('enabled', true);

        expect(capturedAttribute?.key, 'enabled');
        expect(capturedAttribute?.value, true);
      });
    });
  });
}
