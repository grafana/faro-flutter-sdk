import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/telemetry_item_dispatcher.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBatchTransport extends Mock implements BatchTransport {}

class MockSpanRecord extends Mock implements SpanRecord {}

void main() {
  late MockBatchTransport mockTransport;

  setUp(() {
    mockTransport = MockBatchTransport();
  });

  group('TelemetryItemDispatcher:', () {
    test('dispatches event items via addEvent', () {
      final event = Event('tap');
      final item = TelemetryItem.fromEvent(event);

      TelemetryItemDispatcher.dispatch(item, mockTransport);

      verify(() => mockTransport.addEvent(event)).called(1);
    });

    test('dispatches log items via addLog', () {
      final log = FaroLog('message');
      final item = TelemetryItem.fromLog(log);

      TelemetryItemDispatcher.dispatch(item, mockTransport);

      verify(() => mockTransport.addLog(log)).called(1);
    });

    test('dispatches exception items via addExceptions', () {
      final exception = FaroException('type', 'value', null);
      final item = TelemetryItem.fromException(exception);

      TelemetryItemDispatcher.dispatch(item, mockTransport);

      verify(() => mockTransport.addExceptions(exception)).called(1);
    });

    test('dispatches measurement items via addMeasurement', () {
      final measurement = Measurement({'cpu': 12}, 'resource');
      final item = TelemetryItem.fromMeasurement(measurement);

      TelemetryItemDispatcher.dispatch(item, mockTransport);

      verify(() => mockTransport.addMeasurement(measurement)).called(1);
    });

    test('dispatches span items via addSpan', () {
      final span = MockSpanRecord();
      final item = TelemetryItem.fromSpan(span);

      TelemetryItemDispatcher.dispatch(item, mockTransport);

      verify(() => mockTransport.addSpan(span)).called(1);
    });
  });
}
