import 'package:faro/src/models/models.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBatchTransport extends Mock implements BatchTransport {}

class MockUserActionsService extends Mock implements UserActionsService {}

class MockSessionManager extends Mock implements SessionManager {}

void main() {
  late MockBatchTransport mockTransport;
  late MockUserActionsService mockUserActionsService;
  late MockSessionManager mockSessionManager;

  setUpAll(() {
    registerFallbackValue(Event('fallback'));
    registerFallbackValue(SessionActivityKind.active);
  });

  setUp(() {
    mockTransport = MockBatchTransport();
    mockUserActionsService = MockUserActionsService();
    mockSessionManager = MockSessionManager();
    when(
      () => mockSessionManager.checkSession(activity: any(named: 'activity')),
    ).thenAnswer((_) {});
  });

  TelemetryRouter buildRouter({
    BatchTransportResolver? transportResolver,
    SessionManager? sessionManager,
  }) {
    return TelemetryRouter(
      userActionsService: mockUserActionsService,
      sessionManager: sessionManager ?? mockSessionManager,
      transportResolver: transportResolver ?? () => mockTransport,
    );
  }

  group('TelemetryRouter:', () {
    test('buffers events when active action accepts item', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(true);
      final router = buildRouter();

      router.ingest(item);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verifyNever(() => mockTransport.addEvent(item.asEvent!));
    });

    test('dispatches event immediately when skipBuffer is true', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      final router = buildRouter();

      router.ingest(item, skipBuffer: true);

      verifyNever(() => mockUserActionsService.tryBuffer(item));
      verify(() => mockTransport.addEvent(item.asEvent!)).called(1);
    });

    test('dispatches event when buffering is not possible', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(false);
      final router = buildRouter();

      router.ingest(item);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verify(() => mockTransport.addEvent(item.asEvent!)).called(1);
    });

    test('does not dispatch when no transport is available', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(false);
      final router = buildRouter(transportResolver: () => null);

      router.ingest(item);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verifyNever(() => mockTransport.addEvent(item.asEvent!));
    });

    test('checks the session before dispatching telemetry', () {
      final dispatchOrder = <String>[];
      when(
        () => mockSessionManager.checkSession(activity: any(named: 'activity')),
      ).thenAnswer((_) {
        dispatchOrder.add('session-check');
      });
      when(() => mockTransport.addEvent(any())).thenAnswer((_) {
        dispatchOrder.add('dispatch');
      });
      final item = TelemetryItem.fromEvent(Event('tap'));
      final router = buildRouter();

      router.ingest(item, skipBuffer: true);

      expect(dispatchOrder, ['session-check', 'dispatch']);
    });

    test('forwards the activity kind to the session manager', () {
      final item = TelemetryItem.fromMeasurement(
        Measurement({'mem_usage': 1}, 'app_memory'),
      );
      final router = buildRouter();

      router.ingest(item, activity: SessionActivityKind.foregroundOnly);

      // The router does not decide whether vitals count as activity; it
      // just forwards the classification. The session policy interprets
      // it (see session_activity_policy_test.dart).
      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.foregroundOnly,
        ),
      ).called(1);
      verify(() => mockTransport.addMeasurement(item.asMeasurement!)).called(1);
    });

    test('defaults to SessionActivityKind.active', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      final router = buildRouter();

      router.ingest(item, skipBuffer: true);

      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.active,
        ),
      ).called(1);
    });

    test('forwards SessionActivityKind.none', () {
      final item = TelemetryItem.fromEvent(Event('session_extend'));
      final router = buildRouter();

      router.ingest(item, skipBuffer: true, activity: SessionActivityKind.none);

      verify(
        () =>
            mockSessionManager.checkSession(activity: SessionActivityKind.none),
      ).called(1);
    });

    test('never buffers measurements', () {
      final router = buildRouter();
      final item = TelemetryItem.fromMeasurement(
        Measurement({'value': 1}, 'custom'),
      );

      router.ingest(item);

      verifyNever(() => mockUserActionsService.tryBuffer(item));
      verify(() => mockTransport.addMeasurement(item.asMeasurement!)).called(1);
    });
  });
}
