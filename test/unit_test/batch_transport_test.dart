import 'package:fake_async/fake_async.dart';
import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPayload extends Mock implements Payload {}

class MockBatchConfig extends Mock implements BatchConfig {}

class MockBaseTransport extends Mock implements BaseTransport {}

void main() {
  late MockPayload mockPayload;
  late MockBatchConfig mockBatchConfig;
  late MockBaseTransport mockBaseTransport;
  late BatchTransport batchTransport;

  setUp(() {
    mockPayload = MockPayload();
    mockBatchConfig = MockBatchConfig();
    mockBaseTransport = MockBaseTransport();

    when(() => mockBatchConfig.enabled).thenReturn(true);
    when(() => mockBatchConfig.sendTimeout)
        .thenReturn(const Duration(milliseconds: 300));
    when(() => mockBatchConfig.payloadItemLimit).thenReturn(2);
    when(() => mockPayload.events).thenReturn([]);
    when(() => mockPayload.measurements).thenReturn([]);
    when(() => mockPayload.logs).thenReturn([]);
    when(() => mockPayload.exceptions).thenReturn([]);
    when(() => mockPayload.traces).thenReturn(Traces());
    when(() => mockPayload.toJson()).thenReturn({});
    when(() => mockBaseTransport.send(any())).thenAnswer((_) async {});

    batchTransport = BatchTransport(
      payload: mockPayload,
      transports: [mockBaseTransport],
      batchConfig: mockBatchConfig,
    );
  });

  setUpAll(() {
    registerFallbackValue(Payload(Meta()));
  });

  tearDown(() {
    batchTransport.dispose();
  });

  test('addEvent should add event and check payload item limit', () async {
    final event = Event('test_event');
    final mockEvents = <Event>[];
    when(() => mockPayload.events).thenReturn(mockEvents);

    batchTransport.addEvent(event);

    expect(mockEvents.length, equals(1));
    expect(mockEvents[0].toJson(), event.toJson());
  });

  test('addMeasurement should add measurement and check payload item limit',
      () async {
    final measurement = Measurement({'test_value': 12}, 'test');
    final mockMeasurements = <Measurement>[];
    when(() => mockPayload.measurements).thenReturn(mockMeasurements);

    batchTransport.addMeasurement(measurement);

    expect(mockMeasurements.length, equals(1));
    expect(mockMeasurements[0].toJson(), measurement.toJson());
  });

  test('addLog should add log and check payload item limit', () async {
    final log = FaroLog('Test log');
    final mockLogs = <FaroLog>[];
    when(() => mockPayload.logs).thenReturn(mockLogs);

    batchTransport.addLog(log);

    expect(mockLogs.length, equals(1));
    expect(mockLogs[0].toJson(), log.toJson());
  });

  test('addExceptions should add exception and check payload item limit',
      () async {
    final exception = FaroException('TestException', 'Test', {});
    final mockExceptions = <FaroException>[];
    when(() => mockPayload.exceptions).thenReturn(mockExceptions);

    batchTransport.addExceptions(exception);

    expect(mockExceptions.length, equals(1));
    expect(mockExceptions[0].toJson(), exception.toJson());
  });

  test('should flush and send payload and reset it after sendTimeout', () {
    fakeAsync((async) {
      final mockBatchConfig = MockBatchConfig();
      final mockBaseTransport = MockBaseTransport();

      when(() => mockBatchConfig.enabled).thenReturn(true);
      when(() => mockBatchConfig.sendTimeout)
          .thenReturn(const Duration(milliseconds: 300));
      when(() => mockBatchConfig.payloadItemLimit).thenReturn(5);
      when(() => mockBaseTransport.send(any())).thenAnswer((_) async {});

      final payload = Payload(Meta(view: ViewMeta('')));

      final batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: mockBatchConfig,
      );

      batchTransport.addLog(FaroLog('Test log'));
      batchTransport.addEvent(Event('test_event'));
      batchTransport.addMeasurement(Measurement({'test_value': 12}, 'test'));
      batchTransport.addExceptions(FaroException('TestException', 'Test', {}));

      expect(payload.events.length, equals(1));
      expect(payload.measurements.length, equals(1));
      expect(payload.logs.length, equals(1));
      expect(payload.exceptions.length, equals(1));

      async.elapse(const Duration(milliseconds: 400));

      expect(payload.events.length, equals(0));
      expect(payload.measurements.length, equals(0));
      expect(payload.logs.length, equals(0));
      expect(payload.exceptions.length, equals(0));
    });
  });

  test('checkPayloadItemLimit should flush when item limit is reached',
      () async {
    final payload = Payload(Meta(view: ViewMeta('')));
    final event = Event('test_event');

    batchTransport = BatchTransport(
        payload: payload,
        transports: [mockBaseTransport],
        batchConfig: BatchConfig(
            sendTimeout: const Duration(seconds: 5), payloadItemLimit: 1));

    batchTransport.addEvent(event);
    batchTransport.addEvent(event); // This should trigger flush
    verify(() => mockBaseTransport.send(any())).called(2);
  });
  test('dispose should cancel flush timer', () {
    batchTransport.dispose();
    expect(batchTransport.flushTimer, isNull);
  });
  test('isPayloadEmpty should return true if payload is empty', () {
    when(() => mockPayload.events).thenReturn([]);
    when(() => mockPayload.measurements).thenReturn([]);
    when(() => mockPayload.logs).thenReturn([]);
    when(() => mockPayload.exceptions).thenReturn([]);

    expect(batchTransport.isPayloadEmpty(), isTrue);
  });
  test('isPayloadEmpty should return false if payload is not empty', () {
    when(() => mockPayload.events).thenReturn([Event('test_event')]);
    when(() => mockPayload.measurements).thenReturn([]);
    when(() => mockPayload.logs).thenReturn([]);
    when(() => mockPayload.exceptions).thenReturn([]);

    expect(batchTransport.isPayloadEmpty(), isFalse);
  });

  test('resetPayload should clear all payloads', () {
    batchTransport.resetPayload();
    verify(() => mockPayload.events = []).called(1);
    verify(() => mockPayload.measurements = []).called(1);
    verify(() => mockPayload.logs = []).called(1);
    verify(() => mockPayload.exceptions = []).called(1);
  });

  test('constructor with batchConfig disabled should set payloadItemLimit to 1',
      () {
    final batchTransportDisabled = BatchTransport(
      payload: mockPayload,
      batchConfig: BatchConfig(enabled: false),
      transports: [mockBaseTransport],
    );
    expect(batchTransportDisabled.batchConfig.payloadItemLimit, equals(1));
  });

  test(
      // ignore: lines_longer_than_80_chars
      'addEvent should flush immediately if batchConfig is disabled and not wait for timeout',
      () async {
    final payload = Payload(Meta(view: ViewMeta('')));

    final batchTransportDisabled = BatchTransport(
      payload: payload,
      batchConfig: BatchConfig(
        enabled: false,
        sendTimeout: const Duration(seconds: 10),
      ),
      transports: [mockBaseTransport],
    );

    final event = Event('test_event');
    batchTransportDisabled.addEvent(event);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    verify(() => mockBaseTransport.send(any())).called(1);
  });
}
