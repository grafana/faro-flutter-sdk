// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/device_info/dynamic_device_state_provider.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/no_op_batch_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBaseTransport extends Mock implements BaseTransport {}

class MockDynamicDeviceStateProvider extends Mock
    implements DynamicDeviceStateProvider {}

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
        final captured = verify(
          () => mockBaseTransport.send(captureAny()),
        ).captured;
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

    group('dynamic device state', () {
      late MockDynamicDeviceStateProvider dynamicState;

      BatchTransport createTransport(Meta meta) {
        return BatchTransport(
          payload: Payload(meta),
          transports: [mockBaseTransport],
          batchConfig: BatchConfig(
            enabled: false,
            sendTimeout: const Duration(seconds: 10),
          ),
          dynamicDeviceState: dynamicState,
        );
      }

      Map<String, dynamic> sentPayload() {
        return verify(
              () => mockBaseTransport.send(captureAny()),
            ).captured.single
            as Map<String, dynamic>;
      }

      setUp(() {
        dynamicState = MockDynamicDeviceStateProvider();
        when(() => dynamicState.refreshIfStale()).thenReturn(null);
        when(() => dynamicState.current).thenReturn(
          DynamicDeviceState(
            device: Device(batteryLevel: 40, isCharging: true),
            network: Network(connectionType: 'wifi', reachable: false),
          ),
        );
      });

      test('adds the values to the meta of a sent payload', () {
        final transport = createTransport(
          Meta(
            device: Device(manufacturer: 'apple', arch: 'arm64'),
          ),
        );

        transport.addEvent(Event('test_event'));

        final meta = sentPayload()['meta'] as Map<String, dynamic>;
        expect(meta['device'], {
          'manufacturer': 'apple',
          'arch': 'arm64',
          'battery_level': 40,
          'is_charging': true,
        });
        expect(meta['network'], {
          'connection_type': 'wifi',
          'reachable': false,
        });
        transport.dispose();
      });

      test('adds a device object when the meta has none', () {
        final transport = createTransport(Meta());

        transport.addEvent(Event('test_event'));

        final meta = sentPayload()['meta'] as Map<String, dynamic>;
        expect(meta['device'], {'battery_level': 40, 'is_charging': true});
        transport.dispose();
      });

      test('leaves the shared meta untouched', () {
        final meta = Meta(device: Device(manufacturer: 'apple'));
        final transport = createTransport(meta);

        transport.addEvent(Event('test_event'));

        expect(meta.device?.batteryLevel, isNull);
        expect(meta.network, isNull);
        expect(meta.toFaroJson()['device'], {'manufacturer': 'apple'});
        transport.dispose();
      });

      test('omits the fields when no fresh value exists', () {
        when(() => dynamicState.current).thenReturn(null);
        final transport = createTransport(Meta());

        transport.addEvent(Event('test_event'));

        final meta = sentPayload()['meta'] as Map<String, dynamic>;
        expect(meta.containsKey('device'), isFalse);
        expect(meta.containsKey('network'), isFalse);
        transport.dispose();
      });

      test('asks for a refresh each time a signal is captured', () {
        final transport = createTransport(Meta());

        transport
          ..addEvent(Event('event'))
          ..addMeasurement(Measurement({'value': 1}, 'type'))
          ..addLog(FaroLog('log'))
          ..addExceptions(FaroException('type', 'value', {}));

        verify(() => dynamicState.refreshIfStale()).called(4);
        transport.dispose();
      });

      group('at capture time', () {
        DynamicDeviceState stateWith(int batteryLevel) {
          return DynamicDeviceState(
            device: Device(batteryLevel: batteryLevel),
            network: Network(),
          );
        }

        BatchTransport createBatchingTransport() {
          return BatchTransport(
            payload: Payload(Meta()),
            transports: [mockBaseTransport],
            batchConfig: BatchConfig(
              sendTimeout: const Duration(hours: 1),
              payloadItemLimit: 100,
            ),
            dynamicDeviceState: dynamicState,
          );
        }

        List<Map<String, dynamic>> sentPayloads() {
          return verify(
            () => mockBaseTransport.send(captureAny()),
          ).captured.cast<Map<String, dynamic>>();
        }

        int? batteryOf(Map<String, dynamic> payload) {
          final meta = payload['meta'] as Map<String, dynamic>;
          return (meta['device'] as Map<String, dynamic>?)?['battery_level']
              as int?;
        }

        test('keeps the value current at capture, not at send', () {
          when(() => dynamicState.current).thenReturn(stateWith(40));
          final transport = createBatchingTransport();
          transport.addEvent(Event('first'));

          when(() => dynamicState.current).thenReturn(stateWith(10));
          transport.updatePayloadMeta(Meta());

          expect(batteryOf(sentPayloads().single), 40);
          transport.dispose();
        });

        test('a changed value closes the open payload', () {
          when(() => dynamicState.current).thenReturn(stateWith(40));
          final transport = createBatchingTransport();
          transport.addEvent(Event('first'));

          when(() => dynamicState.current).thenReturn(stateWith(39));
          transport.addEvent(Event('second'));
          transport.updatePayloadMeta(Meta());

          final payloads = sentPayloads();
          expect(payloads.map(batteryOf), [40, 39]);
          expect(
            payloads.map((payload) => (payload['events'] as List).length),
            [1, 1],
          );
          transport.dispose();
        });

        test('an unchanged value keeps one payload', () {
          when(() => dynamicState.current).thenReturn(stateWith(40));
          final transport = createBatchingTransport();

          transport.addEvent(Event('first'));
          when(() => dynamicState.current).thenReturn(stateWith(40));
          transport.addEvent(Event('second'));
          transport.updatePayloadMeta(Meta());

          final payload = sentPayloads().single;
          expect((payload['events'] as List).length, 2);
          expect(batteryOf(payload), 40);
          transport.dispose();
        });

        test('a change while the payload is empty sends nothing extra', () {
          when(() => dynamicState.current).thenReturn(stateWith(40));
          final transport = createBatchingTransport();
          transport.addEvent(Event('first'));
          transport.updatePayloadMeta(Meta());
          clearInteractions(mockBaseTransport);

          when(() => dynamicState.current).thenReturn(stateWith(30));
          transport.addEvent(Event('second'));
          transport.updatePayloadMeta(Meta());

          expect(batteryOf(sentPayloads().single), 30);
          transport.dispose();
        });

        test('losing the value starts a payload without the fields', () {
          when(() => dynamicState.current).thenReturn(stateWith(40));
          final transport = createBatchingTransport();
          transport.addEvent(Event('first'));

          when(() => dynamicState.current).thenReturn(null);
          transport.addEvent(Event('second'));
          transport.updatePayloadMeta(Meta());

          expect(sentPayloads().map(batteryOf), [40, null]);
          transport.dispose();
        });
      });

      test('does not read the values for an empty payload', () {
        fakeAsync((async) {
          final transport = BatchTransport(
            payload: Payload(Meta()),
            transports: [mockBaseTransport],
            batchConfig: BatchConfig(sendTimeout: const Duration(seconds: 1)),
            dynamicDeviceState: dynamicState,
          );

          async.elapse(const Duration(seconds: 3));

          verifyNever(() => dynamicState.current);
          verifyNever(() => mockBaseTransport.send(any()));
          transport.dispose();
        });
      });

      test('a payload built outside the transport never carries them', () {
        final recoveredCrash = Payload(
          Meta(device: Device(manufacturer: 'apple')),
        )..exceptions.add(FaroException('type', 'value', {}));

        final meta = recoveredCrash.toJson()['meta'] as Map<String, dynamic>;

        expect(meta['device'], {'manufacturer': 'apple'});
        expect(meta.containsKey('network'), isFalse);
      });
    });

    test('replace applies a new sampling decision', () {
      final factory = BatchTransportFactory();
      factory.reset();
      final first = factory.create(
        initialPayload: Payload(Meta()),
        batchConfig: BatchConfig(),
        transports: [],
        isSampled: true,
      );

      final replacement = factory.replace(
        initialPayload: Payload(Meta()),
        batchConfig: BatchConfig(),
        transports: [],
        isSampled: false,
      );

      expect(replacement, isA<NoOpBatchTransport>());
      expect(identical(first, replacement), isFalse);
      expect(identical(factory.instance, replacement), isTrue);
      factory.reset();
    });
  });
}

class MockSpanRecord extends Mock implements SpanRecord {}
