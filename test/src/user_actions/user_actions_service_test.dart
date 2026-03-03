import 'package:faro/src/models/models.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:faro/src/user_actions/user_action_controller.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBatchTransport extends Mock implements BatchTransport {}

class MockUserActionLifecycleController extends Mock
    implements UserActionLifecycleController {}

void main() {
  late MockBatchTransport mockTransport;
  late MockUserActionLifecycleController mockController;
  late UserActionsService service;

  UserActionLifecycleController controllerFactory(UserAction _) {
    return mockController;
  }

  setUpAll(() {
    registerFallbackValue(Event('fallback'));
    registerFallbackValue(FaroLog('fallback'));
    registerFallbackValue(
      FaroException('fallback', 'fallback', null),
    );
  });

  setUp(() {
    mockTransport = MockBatchTransport();
    mockController = MockUserActionLifecycleController();

    when(() => mockController.attach()).thenReturn(null);
    when(() => mockController.dispose()).thenReturn(null);

    service = UserActionsService(
      transportResolver: () => mockTransport,
      lifecycleControllerFactory: controllerFactory,
    );
  });

  group('UserActionsService:', () {
    test('does not start action when transport is unavailable', () {
      final unavailableService = UserActionsService(
        transportResolver: () => null,
        lifecycleControllerFactory: controllerFactory,
      );

      final action = unavailableService.startUserAction('checkout');

      expect(action, isNull);
      verifyNever(() => mockController.attach());
    });

    test('starts action and attaches lifecycle controller', () {
      final action = service.startUserAction('checkout');

      expect(action, isNotNull);
      expect(service.getActiveUserAction(), same(action));
      verify(() => mockController.attach()).called(1);
    });

    test('prevents concurrent active actions', () {
      final first = service.startUserAction('first');
      final second = service.startUserAction('second');

      expect(first, isNotNull);
      expect(second, isNull);
      expect(service.getActiveUserAction(), same(first));
      verify(() => mockController.attach()).called(1);
    });

    test('tryBuffer only accepts items while action is started', () {
      final action = service.startUserAction('checkout')! as UserAction;

      final first = service.tryBuffer(TelemetryItem.fromEvent(Event('one')));
      expect(first, isTrue);

      action.halt();
      final second = service.tryBuffer(TelemetryItem.fromEvent(Event('two')));
      expect(second, isFalse);

      action.dispose();
      service.dispose();
    });

    test('dispatches buffered telemetry and clears active action on end',
        () async {
      final action = service.startUserAction('checkout')! as UserAction;
      service.tryBuffer(TelemetryItem.fromEvent(Event('event')));
      service.tryBuffer(TelemetryItem.fromLog(FaroLog('log')));
      service.tryBuffer(
        TelemetryItem.fromException(
          FaroException('type', 'value', null),
        ),
      );

      action.end();
      await Future<void>.delayed(Duration.zero);

      // event + summary event
      verify(() => mockTransport.addEvent(any())).called(2);
      verify(() => mockTransport.addLog(any())).called(1);
      verify(() => mockTransport.addExceptions(any())).called(1);
      expect(service.getActiveUserAction(), isNull);
      verify(() => mockController.dispose()).called(1);

      action.dispose();
    });

    test('dispatches buffered telemetry without summary event on cancel',
        () async {
      final action = service.startUserAction('checkout')! as UserAction;
      service.tryBuffer(TelemetryItem.fromEvent(Event('event')));

      action.cancel();
      await Future<void>.delayed(Duration.zero);

      verify(() => mockTransport.addEvent(any())).called(1);
      expect(service.getActiveUserAction(), isNull);
      verify(() => mockController.dispose()).called(1);

      action.dispose();
    });

    test('dispose releases active action resources', () {
      final action = service.startUserAction('checkout')! as UserAction;

      service.dispose();

      expect(service.getActiveUserAction(), isNull);
      verify(() => mockController.dispose()).called(1);

      action.dispose();
    });

    test('tryBuffer returns false when no action is active', () {
      final accepted = service.tryBuffer(
        TelemetryItem.fromEvent(Event('event')),
      );
      expect(accepted, isFalse);
    });
  });
}
