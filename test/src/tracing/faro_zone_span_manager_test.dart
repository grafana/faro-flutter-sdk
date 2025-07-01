// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:faro/src/tracing/faro_zone_span_manager.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockParentSpanLookup extends Mock {
  dynamic call(Symbol key);
}

class MockZoneRunner extends Mock {
  Future<T> call<T>(
    Future<T> Function() callback,
    Map<Object?, Object?> zoneValues,
  );
}

class MockSpan extends Mock implements Span {}

class FakeCallback<T> extends Fake {
  FutureOr<T> call(Span span) => throw UnimplementedError();
}

class FakeSymbol extends Fake implements Symbol {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(MockSpan());
    registerFallbackValue(FakeCallback<String>());
    registerFallbackValue(<Object?, Object?>{});
    registerFallbackValue(FakeSymbol());
  });

  group('FaroZoneSpanManager:', () {
    late FaroZoneSpanManager faroZoneSpanManager;
    late MockParentSpanLookup mockParentSpanLookup;
    late MockZoneRunner mockZoneRunner;
    late MockSpan mockSpan;

    setUp(() {
      mockParentSpanLookup = MockParentSpanLookup();
      mockZoneRunner = MockZoneRunner();
      mockSpan = MockSpan();

      // Stub the status getter to return a default value
      when(() => mockSpan.status).thenReturn(SpanStatusCode.unset);

      faroZoneSpanManager = FaroZoneSpanManager(
        parentSpanLookup: mockParentSpanLookup.call,
        zoneRunner: mockZoneRunner.call,
      );
    });

    group('getActiveSpan:', () {
      test('should return active span when one exists in the zone', () {
        // Arrange
        when(() => mockParentSpanLookup.call(any())).thenReturn(mockSpan);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, equals(mockSpan));
        verify(() => mockParentSpanLookup.call(const Symbol('faroParentSpan')))
            .called(1);
      });

      test('should return null when no span exists in the zone', () {
        // Arrange
        when(() => mockParentSpanLookup.call(any())).thenReturn(null);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, isNull);
        verify(() => mockParentSpanLookup.call(const Symbol('faroParentSpan')))
            .called(1);
      });

      test('should return null when zone value is not a Span', () {
        // Arrange
        when(() => mockParentSpanLookup.call(any())).thenReturn('not-a-span');

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, isNull);
        verify(() => mockParentSpanLookup.call(const Symbol('faroParentSpan')))
            .called(1);
      });

      test('should return null when zone value is another type of object', () {
        // Arrange
        when(() => mockParentSpanLookup.call(any())).thenReturn(42);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, isNull);
        verify(() => mockParentSpanLookup.call(const Symbol('faroParentSpan')))
            .called(1);
      });
    });

    group('executeWithSpan:', () {
      test('should execute callback with span and end span on success',
          () async {
        // Arrange
        var callbackExecuted = false;
        Span? receivedSpan;
        const expectedResult = 'test-result';

        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await faroZoneSpanManager.executeWithSpan<String>(
          mockSpan,
          (span) {
            callbackExecuted = true;
            receivedSpan = span;
            return expectedResult;
          },
        );

        // Assert
        expect(result, equals(expectedResult));
        expect(callbackExecuted, isTrue);
        expect(receivedSpan, equals(mockSpan));
        verify(() => mockSpan.end()).called(1);
        verify(() => mockZoneRunner.call<String>(
              any(),
              {const Symbol('faroParentSpan'): mockSpan},
            )).called(1);
      });

      test('should execute async callback with span and end span on success',
          () async {
        // Arrange
        var callbackExecuted = false;
        Span? receivedSpan;
        const expectedResult = 'async-result';

        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await faroZoneSpanManager.executeWithSpan<String>(
          mockSpan,
          (span) async {
            callbackExecuted = true;
            receivedSpan = span;
            await Future<void>.delayed(Duration.zero); // Simulate async work
            return expectedResult;
          },
        );

        // Assert
        expect(result, equals(expectedResult));
        expect(callbackExecuted, isTrue);
        expect(receivedSpan, equals(mockSpan));
        verify(() => mockSpan.end()).called(1);
      });

      test(
          'should handle exception, set span error status, record exception, and rethrow',
          () async {
        // Arrange
        final testException = Exception('test-exception');

        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act & Assert
        expect(
          () async => faroZoneSpanManager.executeWithSpan<String>(
            mockSpan,
            (span) => throw testException,
          ),
          throwsA(equals(testException)),
        );

        // Verify span error handling
        verify(() => mockSpan.setStatus(
              SpanStatusCode.error,
              message: testException.toString(),
            )).called(1);
        verify(() => mockSpan.recordException(
              testException,
              stackTrace: any(named: 'stackTrace'),
            )).called(1);
        verify(() => mockSpan.end()).called(1);
      });

      test('should ensure span is ended even if exception occurs', () async {
        // Arrange
        final testException = StateError('test-error');

        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act & Assert
        expect(
          () async => faroZoneSpanManager.executeWithSpan<String>(
            mockSpan,
            (span) => throw testException,
          ),
          throwsA(equals(testException)),
        );

        // Verify span is ended in finally block
        verify(() => mockSpan.end()).called(1);
      });

      test(
          'should handle error in span.end() gracefully (end exception masks original)',
          () async {
        // Arrange
        final originalException = Exception('original-exception');
        final endException = Exception('end-exception');

        when(() => mockSpan.end()).thenThrow(endException);
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act & Assert - The end exception will mask the original exception (standard Dart behavior)
        expect(
          () async => faroZoneSpanManager.executeWithSpan<String>(
            mockSpan,
            (span) => throw originalException,
          ),
          throwsA(equals(endException)),
        );

        verify(() => mockSpan.setStatus(
              SpanStatusCode.error,
              message: originalException.toString(),
            )).called(1);
        verify(() => mockSpan.recordException(
              originalException,
              stackTrace: any(named: 'stackTrace'),
            )).called(1);
        verify(() => mockSpan.end()).called(1);
      });

      test('should pass zone values to zone runner', () async {
        // Arrange
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        await faroZoneSpanManager.executeWithSpan<String>(
          mockSpan,
          (span) => 'result',
        );

        // Assert
        verify(() => mockZoneRunner.call<String>(
              any(),
              {const Symbol('faroParentSpan'): mockSpan},
            )).called(1);
      });
    });
  });

  group('FaroZoneSpanManagerFactory:', () {
    late FaroZoneSpanManagerFactory factory;

    setUp(() {
      factory = FaroZoneSpanManagerFactory();
    });

    test('should create FaroZoneSpanManager instance', () {
      // Act
      final result = factory.create();

      // Assert
      expect(result, isA<FaroZoneSpanManager>());
    });

    test('should create FaroZoneSpanManager that works with real Zone',
        () async {
      // Arrange
      final spanManager = factory.create();
      final mockSpan = MockSpan();
      var callbackExecuted = false;

      // Act
      final result = await spanManager.executeWithSpan<String>(
        mockSpan,
        (span) {
          callbackExecuted = true;
          // Verify we can get the active span within the zone
          final activeSpan = spanManager.getActiveSpan();
          expect(activeSpan, equals(mockSpan));
          return 'zone-test-result';
        },
      );

      // Assert
      expect(result, equals('zone-test-result'));
      expect(callbackExecuted, isTrue);
      verify(mockSpan.end).called(1);
    });

    test('should return null for getActiveSpan when no zone context', () {
      // Arrange
      final spanManager = factory.create();

      // Act
      final result = spanManager.getActiveSpan();

      // Assert
      expect(result, isNull);
    });
  });
}
