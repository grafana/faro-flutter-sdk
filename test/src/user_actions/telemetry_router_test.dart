import 'package:faro/src/models/models.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBatchTransport extends Mock implements BatchTransport {}

class MockUserActionsService extends Mock implements UserActionsService {}

void main() {
  late MockBatchTransport mockTransport;
  late MockUserActionsService mockUserActionsService;

  setUp(() {
    mockTransport = MockBatchTransport();
    mockUserActionsService = MockUserActionsService();
  });

  group('TelemetryRouter:', () {
    test('buffers events when active action accepts item', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(true);
      final router = TelemetryRouter(
        transportResolver: () => mockTransport,
        userActionsService: mockUserActionsService,
      );

      router.ingest(item);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verifyNever(() => mockTransport.addEvent(item.asEvent!));
    });

    test('dispatches event immediately when skipBuffer is true', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      final router = TelemetryRouter(
        transportResolver: () => mockTransport,
        userActionsService: mockUserActionsService,
      );

      router.ingest(item, skipBuffer: true);

      verifyNever(() => mockUserActionsService.tryBuffer(item));
      verify(() => mockTransport.addEvent(item.asEvent!)).called(1);
    });

    test('dispatches event when buffering is not possible', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(false);
      final router = TelemetryRouter(
        transportResolver: () => mockTransport,
        userActionsService: mockUserActionsService,
      );

      router.ingest(item);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verify(() => mockTransport.addEvent(item.asEvent!)).called(1);
    });

    test('does not dispatch when no transport is available', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(false);
      final router = TelemetryRouter(
        transportResolver: () => null,
        userActionsService: mockUserActionsService,
      );

      router.ingest(item);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verifyNever(() => mockTransport.addEvent(item.asEvent!));
    });

    test('never buffers measurements', () {
      final router = TelemetryRouter(
        transportResolver: () => mockTransport,
        userActionsService: mockUserActionsService,
      );
      final item = TelemetryItem.fromMeasurement(
        Measurement({'value': 1}, 'custom'),
      );

      router.ingest(item);

      verifyNever(() => mockUserActionsService.tryBuffer(item));
      verify(() => mockTransport.addMeasurement(item.asMeasurement!)).called(1);
    });
  });
}
