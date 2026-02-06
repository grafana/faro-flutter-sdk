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

class MockSpanContextHolder extends Mock implements SpanContextHolder {}

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
      when(() => mockSpan.statusHasBeenSet).thenReturn(false);

      faroZoneSpanManager = FaroZoneSpanManager(
        parentSpanLookup: mockParentSpanLookup.call,
        zoneRunner: mockZoneRunner.call,
      );
    });

    group('getActiveSpan:', () {
      test('should return active span when one exists in the zone', () {
        // Arrange
        final holder = SpanContextHolder(
          span: mockSpan,
          contextScope: ContextScope.callback,
        );
        when(() => mockParentSpanLookup.call(any())).thenReturn(holder);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, equals(mockSpan));
        verify(() => mockParentSpanLookup.call(const Symbol('faroSpanContext')))
            .called(1);
      });

      test('should return null when no span exists in the zone', () {
        // Arrange
        when(() => mockParentSpanLookup.call(any())).thenReturn(null);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, isNull);
        verify(() => mockParentSpanLookup.call(const Symbol('faroSpanContext')))
            .called(1);
      });

      test('should return null when zone value is not a Span', () {
        // Arrange
        when(() => mockParentSpanLookup.call(any())).thenReturn('not-a-span');

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, isNull);
        verify(() => mockParentSpanLookup.call(const Symbol('faroSpanContext')))
            .called(1);
      });

      test('should return null when zone value is another type of object', () {
        // Arrange
        when(() => mockParentSpanLookup.call(any())).thenReturn(42);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, isNull);
        verify(() => mockParentSpanLookup.call(const Symbol('faroSpanContext')))
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
              any(that: predicate<Map<Object?, Object?>>((zoneValues) {
                final holder = zoneValues[const Symbol('faroSpanContext')];
                return holder is SpanContextHolder && holder.span == mockSpan;
              })),
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
              any(that: predicate<Map<Object?, Object?>>((zoneValues) {
                final holder = zoneValues[const Symbol('faroSpanContext')];
                return holder is SpanContextHolder && holder.span == mockSpan;
              })),
            )).called(1);
      });

      test('should set status to OK when statusHasBeenSet is false on success',
          () async {
        // Arrange
        when(() => mockSpan.statusHasBeenSet).thenReturn(false);
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
        verify(() => mockSpan.setStatus(SpanStatusCode.ok)).called(1);
      });

      test(
          'should NOT set status to OK when statusHasBeenSet is true on success',
          () async {
        // Arrange
        when(() => mockSpan.statusHasBeenSet).thenReturn(true);
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
        verifyNever(() => mockSpan.setStatus(SpanStatusCode.ok));
      });

      test('should set status to ERROR when statusHasBeenSet is false on error',
          () async {
        // Arrange
        final testException = Exception('test-exception');
        when(() => mockSpan.statusHasBeenSet).thenReturn(false);
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
      });

      test(
          'should NOT set status to ERROR when statusHasBeenSet is true on error',
          () async {
        // Arrange
        final testException = Exception('test-exception');
        when(() => mockSpan.statusHasBeenSet).thenReturn(true);
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

        // Verify span error handling is NOT called
        verifyNever(() => mockSpan.setStatus(
              SpanStatusCode.error,
              message: testException.toString(),
            ));
        // But exception is still recorded
        verify(() => mockSpan.recordException(
              testException,
              stackTrace: any(named: 'stackTrace'),
            )).called(1);
      });

      test('should respect manually set status during success flow', () async {
        // Arrange
        var statusHasBeenSet = false;
        when(() => mockSpan.statusHasBeenSet)
            .thenAnswer((_) => statusHasBeenSet);
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        await faroZoneSpanManager.executeWithSpan<String>(
          mockSpan,
          (span) {
            // Simulate manually setting status during execution
            statusHasBeenSet = true;
            return 'result';
          },
        );

        // Assert - should NOT have been called since statusHasBeenSet was true when checked
        verifyNever(() => mockSpan.setStatus(SpanStatusCode.ok));
      });

      test('should respect manually set status during error flow', () async {
        // Arrange
        final testException = Exception('test-exception');
        var statusHasBeenSet = false;
        when(() => mockSpan.statusHasBeenSet)
            .thenAnswer((_) => statusHasBeenSet);
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
            (span) {
              // Simulate manually setting status during execution
              statusHasBeenSet = true;
              throw testException;
            },
          ),
          throwsA(equals(testException)),
        );

        // Assert - should NOT have been called since statusHasBeenSet was true when checked
        verifyNever(() => mockSpan.setStatus(
              SpanStatusCode.error,
              message: testException.toString(),
            ));
        // But exception should still be recorded
        verify(() => mockSpan.recordException(
              testException,
              stackTrace: any(named: 'stackTrace'),
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

      // Setup required stubs for the mock span
      when(() => mockSpan.statusHasBeenSet).thenReturn(false);

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

  group('ContextScope behavior:', () {
    group('getActiveSpan with SpanContextHolder:', () {
      late FaroZoneSpanManager faroZoneSpanManager;
      late MockParentSpanLookup mockParentSpanLookup;
      late MockZoneRunner mockZoneRunner;
      late MockSpan mockSpan;

      setUp(() {
        mockParentSpanLookup = MockParentSpanLookup();
        mockZoneRunner = MockZoneRunner();
        mockSpan = MockSpan();

        when(() => mockSpan.status).thenReturn(SpanStatusCode.unset);
        when(() => mockSpan.statusHasBeenSet).thenReturn(false);

        faroZoneSpanManager = FaroZoneSpanManager(
          parentSpanLookup: mockParentSpanLookup.call,
          zoneRunner: mockZoneRunner.call,
        );
      });

      test('should return span when SpanContextHolder is active', () {
        // Arrange
        final holder = SpanContextHolder(
          span: mockSpan,
          contextScope: ContextScope.callback,
        );
        when(() => mockParentSpanLookup.call(any())).thenReturn(holder);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, equals(mockSpan));
      });

      test('should return null when SpanContextHolder is deactivated', () {
        // Arrange
        final holder = SpanContextHolder(
          span: mockSpan,
          contextScope: ContextScope.callback,
        );
        holder.deactivate();
        when(() => mockParentSpanLookup.call(any())).thenReturn(holder);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, isNull);
      });

      test(
          'should still return span when holder uses ContextScope.zone and is active',
          () {
        // Arrange
        final holder = SpanContextHolder(
          span: mockSpan,
          contextScope: ContextScope.zone,
        );
        when(() => mockParentSpanLookup.call(any())).thenReturn(holder);

        // Act
        final result = faroZoneSpanManager.getActiveSpan();

        // Assert
        expect(result, equals(mockSpan));
      });
    });

    group('executeWithSpan with ContextScope:', () {
      late FaroZoneSpanManager faroZoneSpanManager;
      late MockParentSpanLookup mockParentSpanLookup;
      late MockZoneRunner mockZoneRunner;
      late MockSpan mockSpan;

      setUp(() {
        mockParentSpanLookup = MockParentSpanLookup();
        mockZoneRunner = MockZoneRunner();
        mockSpan = MockSpan();

        when(() => mockSpan.status).thenReturn(SpanStatusCode.unset);
        when(() => mockSpan.statusHasBeenSet).thenReturn(false);

        faroZoneSpanManager = FaroZoneSpanManager(
          parentSpanLookup: mockParentSpanLookup.call,
          zoneRunner: mockZoneRunner.call,
        );
      });

      test(
          'should pass SpanContextHolder to zone values instead of span directly',
          () async {
        // Arrange
        SpanContextHolder? capturedHolder;
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final zoneValues =
              invocation.positionalArguments[1] as Map<Object?, Object?>;
          capturedHolder =
              zoneValues[const Symbol('faroSpanContext')] as SpanContextHolder?;
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
        expect(capturedHolder, isNotNull);
        expect(capturedHolder!.span, equals(mockSpan));
      });

      test(
          'should deactivate holder after callback completes with ContextScope.callback (default)',
          () async {
        // Arrange
        SpanContextHolder? capturedHolder;
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final zoneValues =
              invocation.positionalArguments[1] as Map<Object?, Object?>;
          capturedHolder =
              zoneValues[const Symbol('faroSpanContext')] as SpanContextHolder?;
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        await faroZoneSpanManager.executeWithSpan<String>(
          mockSpan,
          (span) => 'result',
        );

        // Assert - holder should be deactivated after callback completes
        expect(capturedHolder, isNotNull);
        expect(capturedHolder!.isActive, isFalse);
      });

      test('should deactivate holder AFTER span.end() is called', () async {
        // Arrange
        SpanContextHolder? capturedHolder;
        bool? holderWasActiveWhenEndCalled;

        when(() => mockSpan.end()).thenAnswer((_) {
          holderWasActiveWhenEndCalled = capturedHolder?.isActive;
        });
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final zoneValues =
              invocation.positionalArguments[1] as Map<Object?, Object?>;
          capturedHolder =
              zoneValues[const Symbol('faroSpanContext')] as SpanContextHolder?;
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        await faroZoneSpanManager.executeWithSpan<String>(
          mockSpan,
          (span) => 'result',
        );

        // Assert - holder should still be active when span.end() is called,
        // then deactivated after as the last thing in the callback scope
        expect(holderWasActiveWhenEndCalled, isTrue);
      });

      test('should NOT deactivate holder with ContextScope.zone', () async {
        // Arrange
        SpanContextHolder? capturedHolder;
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final zoneValues =
              invocation.positionalArguments[1] as Map<Object?, Object?>;
          capturedHolder =
              zoneValues[const Symbol('faroSpanContext')] as SpanContextHolder?;
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        await faroZoneSpanManager.executeWithSpan<String>(
          mockSpan,
          (span) => 'result',
          contextScope: ContextScope.zone,
        );

        // Assert - holder should still be active with ContextScope.zone
        expect(capturedHolder, isNotNull);
        expect(capturedHolder!.isActive, isTrue);
      });

      test('should deactivate holder even when exception occurs', () async {
        // Arrange
        final testException = Exception('test-exception');
        SpanContextHolder? capturedHolder;
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final zoneValues =
              invocation.positionalArguments[1] as Map<Object?, Object?>;
          capturedHolder =
              zoneValues[const Symbol('faroSpanContext')] as SpanContextHolder?;
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

        // Assert - holder should still be deactivated
        expect(capturedHolder, isNotNull);
        expect(capturedHolder!.isActive, isFalse);
      });

      test('should NOT deactivate holder on exception with ContextScope.zone',
          () async {
        // Arrange
        final testException = Exception('test-exception');
        SpanContextHolder? capturedHolder;
        when(() => mockZoneRunner.call<String>(any(), any()))
            .thenAnswer((invocation) async {
          final zoneValues =
              invocation.positionalArguments[1] as Map<Object?, Object?>;
          capturedHolder =
              zoneValues[const Symbol('faroSpanContext')] as SpanContextHolder?;
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act & Assert
        expect(
          () async => faroZoneSpanManager.executeWithSpan<String>(
            mockSpan,
            (span) => throw testException,
            contextScope: ContextScope.zone,
          ),
          throwsA(equals(testException)),
        );

        // Assert - holder should still be active with ContextScope.zone
        expect(capturedHolder, isNotNull);
        expect(capturedHolder!.isActive, isTrue);
      });
    });
  });

  group('SpanContextHolder:', () {
    late MockSpan mockSpan;

    setUp(() {
      mockSpan = MockSpan();
    });

    test('should be active by default', () {
      // Arrange & Act
      final holder = SpanContextHolder(
        span: mockSpan,
        contextScope: ContextScope.callback,
      );

      // Assert
      expect(holder.isActive, isTrue);
    });

    test('should be inactive after deactivate() is called', () {
      // Arrange
      final holder = SpanContextHolder(
        span: mockSpan,
        contextScope: ContextScope.callback,
      );

      // Act
      holder.deactivate();

      // Assert
      expect(holder.isActive, isFalse);
    });

    test('should store the span correctly', () {
      // Arrange & Act
      final holder = SpanContextHolder(
        span: mockSpan,
        contextScope: ContextScope.callback,
      );

      // Assert
      expect(holder.span, equals(mockSpan));
    });

    test('should store the contextScope correctly', () {
      // Arrange & Act
      final holder = SpanContextHolder(
        span: mockSpan,
        contextScope: ContextScope.zone,
      );

      // Assert
      expect(holder.contextScope, equals(ContextScope.zone));
    });
  });

  group('Integration: Real Zone behavior with timers:', () {
    late FaroZoneSpanManager spanManager;
    late MockSpan mockSpan;

    setUp(() {
      spanManager = FaroZoneSpanManagerFactory().create();
      mockSpan = MockSpan();
      when(() => mockSpan.statusHasBeenSet).thenReturn(false);
    });

    test(
        'ContextScope.callback: getActiveSpan returns null after callback completes',
        () async {
      // Arrange
      Span? activeSpanDuringCallback;
      Span? activeSpanAfterCallback;
      final completer = Completer<void>();

      // Act
      await spanManager.executeWithSpan<void>(
        mockSpan,
        (span) async {
          activeSpanDuringCallback = spanManager.getActiveSpan();

          // Schedule a timer that will fire after the callback completes
          Timer(Duration.zero, () {
            activeSpanAfterCallback = spanManager.getActiveSpan();
            completer.complete();
          });
        },
        // Using default ContextScope.callback
      );

      // Wait for the timer to fire
      await completer.future;

      // Assert
      expect(activeSpanDuringCallback, equals(mockSpan),
          reason: 'Span should be active during callback');
      expect(activeSpanAfterCallback, isNull,
          reason: 'Span should be deactivated after callback completes');
    });

    test(
        'ContextScope.zone: getActiveSpan returns span even after callback completes',
        () async {
      // Arrange
      Span? activeSpanDuringCallback;
      Span? activeSpanAfterCallback;
      final completer = Completer<void>();

      // Act
      await spanManager.executeWithSpan<void>(
        mockSpan,
        (span) async {
          activeSpanDuringCallback = spanManager.getActiveSpan();

          // Schedule a timer that will fire after the callback completes
          Timer(Duration.zero, () {
            activeSpanAfterCallback = spanManager.getActiveSpan();
            completer.complete();
          });
        },
        contextScope: ContextScope.zone,
      );

      // Wait for the timer to fire
      await completer.future;

      // Assert
      expect(activeSpanDuringCallback, equals(mockSpan),
          reason: 'Span should be active during callback');
      expect(activeSpanAfterCallback, equals(mockSpan),
          reason: 'Span should remain active with ContextScope.zone');
    });

    test('nested spans work correctly with ContextScope.callback', () async {
      // Arrange
      final parentSpan = MockSpan();
      final childSpan = MockSpan();
      when(() => parentSpan.statusHasBeenSet).thenReturn(false);
      when(() => childSpan.statusHasBeenSet).thenReturn(false);

      Span? activeSpanInParent;
      Span? activeSpanInChild;
      Span? activeSpanAfterChild;

      // Act
      await spanManager.executeWithSpan<void>(
        parentSpan,
        (parent) async {
          activeSpanInParent = spanManager.getActiveSpan();

          await spanManager.executeWithSpan<void>(
            childSpan,
            (child) async {
              activeSpanInChild = spanManager.getActiveSpan();
            },
          );

          activeSpanAfterChild = spanManager.getActiveSpan();
        },
      );

      // Assert
      expect(activeSpanInParent, equals(parentSpan));
      expect(activeSpanInChild, equals(childSpan));
      expect(activeSpanAfterChild, equals(parentSpan),
          reason: 'After child completes, parent should be active again');
    });
  });
}
