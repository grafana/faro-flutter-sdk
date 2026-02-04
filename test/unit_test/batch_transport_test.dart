// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/no_op_batch_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBaseTransport extends Mock implements BaseTransport {}

void main() {
  late MockBaseTransport mockBaseTransport;

  setUp(() {
    mockBaseTransport = MockBaseTransport();
    when(() => mockBaseTransport.send(any())).thenAnswer((_) async {});
  });

  setUpAll(() {
    registerFallbackValue(Payload(Meta()));
  });

  group('BatchTransport:', () {
    test('addEvent should add event to payload', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 100,
        ),
      );

      batchTransport.addEvent(Event('test_event'));

      expect(batchTransport.payloadSize(), equals(1));
      batchTransport.dispose();
    });

    test('addMeasurement should add measurement to payload', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 100,
        ),
      );

      batchTransport.addMeasurement(Measurement({'test_value': 12}, 'test'));

      expect(batchTransport.payloadSize(), equals(1));
      batchTransport.dispose();
    });

    test('addLog should add log to payload', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 100,
        ),
      );

      batchTransport.addLog(FaroLog('Test log'));

      expect(batchTransport.payloadSize(), equals(1));
      batchTransport.dispose();
    });

    test('addExceptions should add exception to payload', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 100,
        ),
      );

      batchTransport.addExceptions(FaroException('TestException', 'Test', {}));

      expect(batchTransport.payloadSize(), equals(1));
      batchTransport.dispose();
    });

    test('should flush and send payload after sendTimeout', () {
      fakeAsync((async) {
        final payload = Payload(Meta(view: ViewMeta('')));

        final batchTransport = BatchTransport(
          payload: payload,
          transports: [mockBaseTransport],
          batchConfig: BatchConfig(
            enabled: true,
            sendTimeout: const Duration(milliseconds: 300),
            payloadItemLimit: 100,
          ),
        );

        batchTransport.addLog(FaroLog('Test log'));
        batchTransport.addEvent(Event('test_event'));

        // Before timeout, payload should have items
        expect(batchTransport.payloadSize(), equals(2));

        // After timeout, payload should be flushed and reset
        async.elapse(const Duration(milliseconds: 400));

        expect(batchTransport.payloadSize(), equals(0));

        // Verify send was called with the correct payload content
        final captured =
            verify(() => mockBaseTransport.send(captureAny())).captured;
        expect(captured, hasLength(1));

        final sentPayload = captured.single as Map<String, dynamic>;
        expect(sentPayload['logs'], isNotEmpty);
        expect(sentPayload['events'], isNotEmpty);
      });
    });

    test('should flush when payload item limit is reached', () async {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 1,
        ),
      );

      batchTransport.addEvent(Event('event1'));
      batchTransport.addEvent(Event('event2'));

      // Each event triggers a flush because limit is 1
      verify(() => mockBaseTransport.send(any())).called(2);
      batchTransport.dispose();
    });

    test('dispose should prevent further flushes from timer', () {
      fakeAsync((async) {
        final payload = Payload(Meta(view: ViewMeta('')));

        final batchTransport = BatchTransport(
          payload: payload,
          transports: [mockBaseTransport],
          batchConfig: BatchConfig(
            enabled: true,
            sendTimeout: const Duration(milliseconds: 300),
            payloadItemLimit: 100,
          ),
        );

        batchTransport.addLog(FaroLog('Test log'));

        // Dispose before timeout
        batchTransport.dispose();

        // Elapse past the timeout
        async.elapse(const Duration(milliseconds: 400));

        // Transport should NOT have been called (timer was cancelled)
        verifyNever(() => mockBaseTransport.send(any()));
      });
    });

    test('isPayloadEmpty should return true when payload is empty', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 100,
        ),
      );

      expect(batchTransport.isPayloadEmpty(), isTrue);
      batchTransport.dispose();
    });

    test('isPayloadEmpty should return false when payload has items', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 100,
        ),
      );

      batchTransport.addEvent(Event('test_event'));

      expect(batchTransport.isPayloadEmpty(), isFalse);
      batchTransport.dispose();
    });

    test('resetPayload should clear all items', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: true,
          sendTimeout: const Duration(seconds: 10),
          payloadItemLimit: 100,
        ),
      );

      batchTransport.addEvent(Event('test_event'));
      batchTransport.addLog(FaroLog('test log'));

      expect(batchTransport.payloadSize(), equals(2));

      batchTransport.resetPayload();

      expect(batchTransport.payloadSize(), equals(0));
      batchTransport.dispose();
    });

    test('when batching disabled should flush immediately on each add', () {
      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
          enabled: false,
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      batchTransport.addEvent(Event('event1'));

      // Should flush immediately (not wait for timeout)
      verify(() => mockBaseTransport.send(any())).called(1);
    });
  });

  group('NoOpBatchTransport:', () {
    test('should drop events silently', () {
      final transport = NoOpBatchTransport();

      transport.addEvent(Event('test_event'));

      expect(transport.payloadSize(), equals(0));
      expect(transport.isPayloadEmpty(), isTrue);
    });

    test('should drop logs silently', () {
      final transport = NoOpBatchTransport();

      transport.addLog(FaroLog('Test log'));

      expect(transport.payloadSize(), equals(0));
    });

    test('should drop measurements silently', () {
      final transport = NoOpBatchTransport();

      transport.addMeasurement(Measurement({'test_value': 12}, 'test'));

      expect(transport.payloadSize(), equals(0));
    });

    test('should drop exceptions silently', () {
      final transport = NoOpBatchTransport();

      transport.addExceptions(FaroException('TestException', 'Test', {}));

      expect(transport.payloadSize(), equals(0));
    });

    test('should drop spans silently', () {
      final transport = NoOpBatchTransport();

      final mockSpanRecord = MockSpanRecord();
      transport.addSpan(mockSpanRecord);

      expect(transport.payloadSize(), equals(0));
    });
  });

  group('BatchTransportFactory:', () {
    test('should return BatchTransport when sampled', () {
      final factory = BatchTransportFactory();
      factory.reset();

      final transport = factory.create(
        initialPayload: Payload(Meta()),
        batchConfig: BatchConfig(),
        transports: [],
        isSampled: true,
      );

      expect(transport, isA<BatchTransport>());
      expect(transport, isNot(isA<NoOpBatchTransport>()));
      factory.reset();
    });

    test('should return NoOpBatchTransport when not sampled', () {
      final factory = BatchTransportFactory();
      factory.reset();

      final transport = factory.create(
        initialPayload: Payload(Meta()),
        batchConfig: BatchConfig(),
        transports: [],
        isSampled: false,
      );

      expect(transport, isA<NoOpBatchTransport>());
      factory.reset();
    });
  });
}

class MockSpanRecord extends Mock implements SpanRecord {}
