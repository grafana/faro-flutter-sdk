import 'package:faro/src/tracing/faro_user_action_span_processor.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class MockSpanProcessor extends Mock implements otel_sdk.SpanProcessor {}

class MockReadWriteSpan extends Mock implements otel_sdk.ReadWriteSpan {}

class MockContext extends Mock implements otel_api.Context {}

void main() {
  late MockSpanProcessor mockDelegate;
  late MockReadWriteSpan mockSpan;
  late MockContext mockContext;

  setUpAll(() {
    registerFallbackValue(otel_api.Attribute.fromString('', ''));
  });

  setUp(() {
    mockDelegate = MockSpanProcessor();
    mockSpan = MockReadWriteSpan();
    mockContext = MockContext();
  });

  group('FaroUserActionSpanProcessor:', () {
    group('onStart:', () {
      test(
        'should set action attributes on span '
        'when action is in started state',
        () {
          final action = UserAction(name: 'checkout');
          final processor = FaroUserActionSpanProcessor(
            delegate: mockDelegate,
            activeUserActionResolver: () => action,
          );

          processor.onStart(mockSpan, mockContext);

          final captured = verify(
            () => mockSpan.setAttribute(captureAny()),
          ).captured;

          expect(captured, hasLength(2));
          final nameAttr = captured[0] as otel_api.Attribute;
          final parentIdAttr = captured[1] as otel_api.Attribute;

          expect(nameAttr.key, equals('faro.action.user.name'));
          expect(nameAttr.value, equals('checkout'));
          expect(parentIdAttr.key, equals('faro.action.user.parentId'));
          expect(parentIdAttr.value, equals(action.id));

          action.dispose();
        },
      );

      test(
        'should NOT set attributes when no active action',
        () {
          final processor = FaroUserActionSpanProcessor(
            delegate: mockDelegate,
            activeUserActionResolver: () => null,
          );

          processor.onStart(mockSpan, mockContext);

          verifyNever(() => mockSpan.setAttribute(any()));
        },
      );

      test(
        'should NOT set attributes when action is in halted state',
        () {
          final action = UserAction(name: 'checkout');
          action.halt();

          final processor = FaroUserActionSpanProcessor(
            delegate: mockDelegate,
            activeUserActionResolver: () => action,
          );

          processor.onStart(mockSpan, mockContext);

          verifyNever(() => mockSpan.setAttribute(any()));

          action.dispose();
        },
      );

      test(
        'should NOT set attributes when action is in ended state',
        () {
          final action = UserAction(name: 'checkout');
          action.end();

          final processor = FaroUserActionSpanProcessor(
            delegate: mockDelegate,
            activeUserActionResolver: () => action,
          );

          processor.onStart(mockSpan, mockContext);

          verifyNever(() => mockSpan.setAttribute(any()));

          action.dispose();
        },
      );

      test(
        'should NOT set attributes when action is in cancelled state',
        () {
          final action = UserAction(name: 'checkout');
          action.cancel();

          final processor = FaroUserActionSpanProcessor(
            delegate: mockDelegate,
            activeUserActionResolver: () => action,
          );

          processor.onStart(mockSpan, mockContext);

          verifyNever(() => mockSpan.setAttribute(any()));

          action.dispose();
        },
      );

      test(
        'should set action attributes on all span kinds',
        () {
          final action = UserAction(name: 'checkout');
          final processor = FaroUserActionSpanProcessor(
            delegate: mockDelegate,
            activeUserActionResolver: () => action,
          );

          for (final kind in otel_api.SpanKind.values) {
            reset(mockSpan);
            when(() => mockSpan.kind).thenReturn(kind);
            processor.onStart(mockSpan, mockContext);

            verify(() => mockSpan.setAttribute(any())).called(2);
          }

          action.dispose();
        },
      );

      test(
        'should always delegate onStart to wrapped processor',
        () {
          final processor = FaroUserActionSpanProcessor(
            delegate: mockDelegate,
            activeUserActionResolver: () => null,
          );

          processor.onStart(mockSpan, mockContext);

          verify(() => mockDelegate.onStart(mockSpan, mockContext)).called(1);
        },
      );
    });

    group('delegation:', () {
      test('should delegate onEnd to wrapped processor', () {
        final mockReadOnlySpan = MockReadWriteSpan();
        final processor = FaroUserActionSpanProcessor(
          delegate: mockDelegate,
          activeUserActionResolver: () => null,
        );

        processor.onEnd(mockReadOnlySpan);

        verify(() => mockDelegate.onEnd(mockReadOnlySpan)).called(1);
      });

      test('should delegate shutdown to wrapped processor', () {
        final processor = FaroUserActionSpanProcessor(
          delegate: mockDelegate,
          activeUserActionResolver: () => null,
        );

        processor.shutdown();

        verify(() => mockDelegate.shutdown()).called(1);
      });

      test('should delegate forceFlush to wrapped processor', () {
        final processor = FaroUserActionSpanProcessor(
          delegate: mockDelegate,
          activeUserActionResolver: () => null,
        );

        processor.forceFlush();

        verify(() => mockDelegate.forceFlush()).called(1);
      });
    });
  });
}
