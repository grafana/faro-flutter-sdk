import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/device_info/dynamic_device_state_provider.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/user_actions/telemetry_item_dispatcher.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBatchTransport extends Mock implements BatchTransport {}

class MockUserActionsService extends Mock implements UserActionsService {}

class MockBaseTransport extends Mock implements BaseTransport {}

class MockDynamicDeviceStateProvider extends Mock
    implements DynamicDeviceStateProvider {}

class MockSessionManager extends Mock implements SessionManager {}

void main() {
  late MockBatchTransport mockTransport;
  late MockUserActionsService mockUserActionsService;
  late MockSessionManager mockSessionManager;

  setUpAll(() {
    registerFallbackValue(Event('fallback'));
    registerFallbackValue(TelemetryItem.fromEvent(Event('fallback')));
    registerFallbackValue(SessionActivityKind.meaningful);
    registerFallbackValue(<String, dynamic>{});
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
    test('reads the device state before it buffers an item', () {
      const capture = DynamicDeviceStateCapture(null);
      when(() => mockTransport.captureDynamicDeviceState()).thenReturn(capture);
      final item = TelemetryItem.fromEvent(Event('tap'));
      DynamicDeviceStateCapture? seenWhenBuffered;
      when(() => mockUserActionsService.tryBuffer(item)).thenAnswer((_) {
        seenWhenBuffered = item.deviceState;
        return true;
      });
      final router = buildRouter();

      router.ingest(item, activity: SessionActivityKind.meaningful);

      expect(seenWhenBuffered, same(capture));
    });

    test('sends the captured device state with the item', () {
      const capture = DynamicDeviceStateCapture(null);
      when(() => mockTransport.captureDynamicDeviceState()).thenReturn(capture);
      when(
        () => mockTransport.addEvent(any(), capture: any(named: 'capture')),
      ).thenAnswer((_) {});
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(false);
      final router = buildRouter();

      router.ingest(item, activity: SessionActivityKind.meaningful);

      verify(
        () => mockTransport.addEvent(item.asEvent!, capture: capture),
      ).called(1);
    });

    group('with a real transport', () {
      late MockBaseTransport baseTransport;
      late MockDynamicDeviceStateProvider dynamicState;
      late BatchTransport realTransport;

      DynamicDeviceState connection(String type) {
        return DynamicDeviceState(
          device: Device(),
          network: Network(connectionType: type),
        );
      }

      setUp(() {
        baseTransport = MockBaseTransport();
        dynamicState = MockDynamicDeviceStateProvider();
        when(() => baseTransport.send(any())).thenAnswer((_) async {});
        when(() => dynamicState.refreshIfStale()).thenReturn(null);
        realTransport = BatchTransport(
          payload: Payload(Meta()),
          transports: [baseTransport],
          batchConfig: BatchConfig(
            sendTimeout: const Duration(hours: 1),
            payloadItemLimit: 100,
          ),
          dynamicDeviceState: dynamicState,
        );
      });

      tearDown(() => realTransport.dispose());

      String? connectionOf(Map<String, dynamic> payload) {
        final meta = payload['meta'] as Map<String, dynamic>;
        return (meta['network'] as Map<String, dynamic>?)?['connection_type']
            as String?;
      }

      test('a log held during a user action keeps the connection it was '
          'captured on', () {
        final heldItems = <TelemetryItem>[];
        when(() => mockUserActionsService.tryBuffer(any())).thenAnswer((call) {
          heldItems.add(call.positionalArguments.single as TelemetryItem);
          return true;
        });
        final router = buildRouter(transportResolver: () => realTransport);
        when(() => dynamicState.current).thenReturn(connection('wifi'));

        router.ingest(
          TelemetryItem.fromLog(FaroLog('while on wifi')),
          activity: SessionActivityKind.meaningful,
        );
        when(() => dynamicState.current).thenReturn(connection('cell'));
        for (final item in heldItems) {
          TelemetryItemDispatcher.dispatch(item, realTransport);
        }
        realTransport.updatePayloadMeta(Meta());

        final payloads = verify(
          () => baseTransport.send(captureAny()),
        ).captured.cast<Map<String, dynamic>>();
        expect(payloads.map(connectionOf), ['wifi']);
      });

      test('items captured live after the switch carry the new connection', () {
        final heldItems = <TelemetryItem>[];
        when(() => mockUserActionsService.tryBuffer(any())).thenAnswer((call) {
          heldItems.add(call.positionalArguments.single as TelemetryItem);
          return true;
        });
        final router = buildRouter(transportResolver: () => realTransport);
        when(() => dynamicState.current).thenReturn(connection('wifi'));
        router.ingest(
          TelemetryItem.fromLog(FaroLog('while on wifi')),
          activity: SessionActivityKind.meaningful,
        );

        when(() => dynamicState.current).thenReturn(connection('cell'));
        router.ingest(
          TelemetryItem.fromMeasurement(Measurement({'value': 1}, 'type')),
          activity: SessionActivityKind.meaningful,
        );
        for (final item in heldItems) {
          TelemetryItemDispatcher.dispatch(item, realTransport);
        }
        realTransport.updatePayloadMeta(Meta());

        final payloads = verify(
          () => baseTransport.send(captureAny()),
        ).captured.cast<Map<String, dynamic>>();
        expect(payloads.map(connectionOf), ['cell', 'wifi']);
      });
    });

    test('buffers events when active action accepts item', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(true);
      final router = buildRouter();

      router.ingest(item, activity: SessionActivityKind.meaningful);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verifyNever(() => mockTransport.addEvent(item.asEvent!));
    });

    test('dispatches event immediately when skipBuffer is true', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      final router = buildRouter();

      router.ingest(
        item,
        activity: SessionActivityKind.meaningful,
        skipBuffer: true,
      );

      verifyNever(() => mockUserActionsService.tryBuffer(item));
      verify(() => mockTransport.addEvent(item.asEvent!)).called(1);
    });

    test('dispatches event when buffering is not possible', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(false);
      final router = buildRouter();

      router.ingest(item, activity: SessionActivityKind.meaningful);

      verify(() => mockUserActionsService.tryBuffer(item)).called(1);
      verify(() => mockTransport.addEvent(item.asEvent!)).called(1);
    });

    test('does not dispatch when no transport is available', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      when(() => mockUserActionsService.tryBuffer(item)).thenReturn(false);
      final router = buildRouter(transportResolver: () => null);

      router.ingest(item, activity: SessionActivityKind.meaningful);

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

      router.ingest(
        item,
        activity: SessionActivityKind.meaningful,
        skipBuffer: true,
      );

      expect(dispatchOrder, ['session-check', 'dispatch']);
    });

    test('forwards the activity kind to the session manager', () {
      final item = TelemetryItem.fromMeasurement(
        Measurement({'mem_usage': 1}, 'app_memory'),
      );
      final router = buildRouter();

      router.ingest(item, activity: SessionActivityKind.passive);

      // The router does not decide whether vitals count as activity; it
      // just forwards the classification. The session policy interprets
      // it (see session_activity_policy_test.dart).
      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.passive,
        ),
      ).called(1);
      verify(() => mockTransport.addMeasurement(item.asMeasurement!)).called(1);
    });

    test('forwards SessionActivityKind.meaningful', () {
      final item = TelemetryItem.fromEvent(Event('tap'));
      final router = buildRouter();

      router.ingest(
        item,
        activity: SessionActivityKind.meaningful,
        skipBuffer: true,
      );

      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(1);
    });

    test('forwards SessionActivityKind.passive', () {
      final item = TelemetryItem.fromEvent(Event('session_start'));
      final router = buildRouter();

      router.ingest(
        item,
        activity: SessionActivityKind.passive,
        skipBuffer: true,
      );

      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.passive,
        ),
      ).called(1);
    });

    test('never buffers measurements', () {
      final router = buildRouter();
      final item = TelemetryItem.fromMeasurement(
        Measurement({'value': 1}, 'custom'),
      );

      router.ingest(item, activity: SessionActivityKind.passive);

      verifyNever(() => mockUserActionsService.tryBuffer(item));
      verify(() => mockTransport.addMeasurement(item.asMeasurement!)).called(1);
    });
  });
}
