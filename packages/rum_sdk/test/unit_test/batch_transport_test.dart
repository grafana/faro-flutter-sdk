import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/configurations/batch_config.dart';
import 'package:rum_sdk/src/models/models.dart';
import 'package:rum_sdk/src/transport/rum_base_transport.dart';
import 'package:rum_sdk/src/transport/batch_transport.dart';

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
    mockBaseTransport =MockBaseTransport();

    when(() => mockBatchConfig.enabled).thenReturn(true);
    when(() => mockBatchConfig.sendTimeout).thenReturn(Duration(seconds: 1));
    when(() => mockBatchConfig.payloadItemLimit).thenReturn(2);
    when(() => mockPayload.events).thenReturn([]);
    when(() => mockPayload.measurements).thenReturn([]);
    when(() => mockPayload.logs).thenReturn([]);
    when(() => mockPayload.exceptions).thenReturn([]);
    when(() => mockBaseTransport.send(any())).thenAnswer((_) async {});
    batchTransport = BatchTransport(
      payload: mockPayload,
      transports: [mockBaseTransport],
      batchConfig: BatchConfig(),
    );

  });

  setUpAll((){
    registerFallbackValue(Payload(Meta()));

  });

  tearDown(() {
    batchTransport.dispose();
  });

  test('addEvent should add event and check payload item limit', () async {
    final event = Event("test_event");
    await batchTransport.addEvent(event);
    verify(() => mockPayload.events.add(event)).called(1);
    expect(batchTransport.items, equals(1));
  });

  test('addMeasurement should add measurement and check payload item limit', () async {
    final measurement = Measurement({"test_value":12}, "test") ;
    await batchTransport.addMeasurement(measurement);
    verify(() => mockPayload.measurements.add(measurement)).called(1);
    expect(batchTransport.items, equals(1));
  });

  test('addLog should add log and check payload item limit', () async {
    final log = RumLog("Test log");
    await batchTransport.addLog(log);
    verify(() => mockPayload.logs.add(log)).called(1);
    expect(batchTransport.items, equals(1));
  });

  test('addExceptions should add exception and check payload item limit', () async {
    final exception = RumException("TestException", "Test", {});
    await batchTransport.addExceptions(exception);
    verify(() => mockPayload.exceptions.add(exception)).called(1);
    expect(batchTransport.items, equals(1));
  });
  //
  test('flush should send payload and reset it', () async {
    final exception = RumException("TestException", "Test", {});
    await batchTransport.addExceptions(exception);
    await batchTransport.flush();
    verify(() => mockBaseTransport.send(any())).called(1);
      verify(() => mockPayload.events = []).called(1);
      verify(() => mockPayload.measurements = []).called(1);
      verify(() => mockPayload.logs = []).called(1);
      verify(() => mockPayload.exceptions = []).called(1);
  });
  test('flush should not send empty payload', () async {
    when(() => mockPayload.events).thenReturn([]);
    when(() => mockPayload.measurements).thenReturn([]);
    when(() => mockPayload.logs).thenReturn([]);
    when(() => mockPayload.exceptions).thenReturn([]);
    await batchTransport.flush();
    verifyNever(() => mockBaseTransport.send(any()));
  });
  test('checkPayloadItemLimit should flush when item limit is reached', () async {
    final event = Event("test_event");
    batchTransport = BatchTransport(
      payload: mockPayload,
      transports: [mockBaseTransport],
      batchConfig:BatchConfig(sendTimeout: const Duration(seconds:  5),payloadItemLimit: 1)
    );
    await batchTransport.addEvent(event);
    await batchTransport.addEvent(event); // This should trigger flush
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
    when(() => mockPayload.events).thenReturn([Event("test_event")]);
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
  test('constructor with batchConfig disabled should set payloadItemLimit to 1', () {
    final batchTransportDisabled = BatchTransport(
      payload: mockPayload,
      batchConfig: BatchConfig(enabled: false),
      transports: [mockBaseTransport],
    );
    expect(batchTransportDisabled.batchConfig.payloadItemLimit, equals(1));
  });
  test('addEvent should flush immediately if batchConfig is disabled and not wait for timeout', () async {
    when(() => mockBatchConfig.enabled).thenReturn(false);
    final batchTransportDisabled = BatchTransport(
      payload: mockPayload,
      batchConfig: BatchConfig(sendTimeout:  const Duration(seconds:10)),
      transports: [mockBaseTransport],
    );

    final event = Event("test_event");
    await batchTransportDisabled.addEvent(event);
    await Future.delayed(const Duration(milliseconds: 500));
    verify(() => mockBaseTransport.send(any())).called(1);
  });
}
