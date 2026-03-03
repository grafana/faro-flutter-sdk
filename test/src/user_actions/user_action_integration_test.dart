import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/start_user_action_options.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBaseTransport extends Mock implements BaseTransport {}

void main() {
  const actionSettleDelay = Duration(milliseconds: 130);

  late MockBaseTransport mockTransport;
  late Faro faro;
  UserActionLifecycleSignalChannel lifecycleSignalChannel() =>
      pod.resolve(userActionLifecycleSignalChannelProvider);

  Future<void> completeActiveAction({
    required String source,
  }) async {
    if (faro.getActiveUserAction() == null) {
      return;
    }
    lifecycleSignalChannel().emitActivity(source: source);
    await Future<void>.delayed(actionSettleDelay);
  }

  Future<void> waitForAutoCancellation() async {
    await Future<void>.delayed(actionSettleDelay);
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    BatchTransportFactory().reset();

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Mock PackageInfo
    PackageInfo.setMockInitialValues(
      appName: 'test-app',
      packageName: 'com.example.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );

    mockTransport = MockBaseTransport();
    when(() => mockTransport.send(any())).thenAnswer((_) async {});

    // Reset Faro singleton
    faro = Faro();
    faro.transports = [mockTransport];
  });

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  tearDown(() async {
    await completeActiveAction(source: 'test.teardown');
    BatchTransportFactory().reset();
  });

  group('User Action Integration:', () {
    test('should start user action successfully', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );
      clearInteractions(mockTransport);

      final action = faro.startUserAction('test-action');

      expect(action, isNotNull);
      expect(action!.name, equals('test-action'));
      expect(action.importance, equals(UserActionConstants.importanceNormal));
    });

    test('should not allow multiple concurrent user actions', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );
      clearInteractions(mockTransport);

      final action1 = faro.startUserAction('action-1');
      expect(action1, isNotNull);

      final action2 = faro.startUserAction('action-2');
      expect(action2, isNull);

      // Clean up
      await completeActiveAction(source: 'test.concurrent_cleanup');
    });

    test('should buffer pushEvent when action is active', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );
      clearInteractions(mockTransport);

      faro.startUserAction('test-action');

      // Push event while action is active
      faro.pushEvent('test-event', attributes: {'key': 'value'});

      // Event should NOT be sent immediately
      verifyNever(() => mockTransport.send(any()));

      // End the action
      await completeActiveAction(source: 'test.buffer_event');

      // Now events should be sent (the buffered event + final action event)
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(() => mockTransport.send(any())).called(greaterThanOrEqualTo(1));
    });

    test('should buffer pushLog when action is active', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );
      clearInteractions(mockTransport);

      faro.startUserAction('test-action');

      // Push log while action is active
      faro.pushLog('test log', level: LogLevel.info);

      // Log should NOT be sent immediately
      verifyNever(() => mockTransport.send(any()));

      // End the action
      await completeActiveAction(source: 'test.buffer_log');

      // Now logs should be sent
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(() => mockTransport.send(any())).called(greaterThanOrEqualTo(1));
    });

    test('should buffer pushError when action is active', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );
      clearInteractions(mockTransport);

      faro.startUserAction('test-action');

      // Push error while action is active
      faro.pushError(type: 'TestError', value: 'Test error message');

      // Error should NOT be sent immediately
      verifyNever(() => mockTransport.send(any()));

      // End the action
      await completeActiveAction(source: 'test.buffer_error');

      // Now errors should be sent
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(() => mockTransport.send(any())).called(greaterThanOrEqualTo(1));
    });

    test('should send items immediately when no action is active', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      // Push without active action
      faro.pushEvent('test-event');

      // Should be sent immediately
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(() => mockTransport.send(any())).called(greaterThanOrEqualTo(1));
    });

    test('should send items immediately when action is halted', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      final action = faro.startUserAction('test-action');
      expect(action, isNotNull);

      // Trigger pending HTTP to move action into halted state after follow-up.
      lifecycleSignalChannel().emitPendingStart(
        source: 'http',
        operationId: 'req-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // Push event - should NOT be buffered (sent immediately)
      faro.pushEvent('test-event');

      // Should be sent immediately
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(() => mockTransport.send(any())).called(greaterThanOrEqualTo(1));

      // Clean up
      lifecycleSignalChannel().emitPendingEnd(
        source: 'http',
        operationId: 'req-1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('should enrich buffered items with action metadata on end', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      final action = faro.startUserAction('test-action');
      expect(action, isNotNull);

      // Push telemetry
      faro.pushEvent('buffered-event');
      faro.pushLog('buffered log', level: LogLevel.info);

      // End the action
      await completeActiveAction(source: 'test.enrich_on_end');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify items were sent with action context
      final captured = verify(() => mockTransport.send(captureAny())).captured;
      expect(captured, isNotEmpty);

      // Check that at least one payload contains events with action context
      final hasEnrichedEvent = captured.any((payload) {
        final map = payload as Map<String, dynamic>;
        if (map['events'] != null && (map['events'] as List).isNotEmpty) {
          final events = map['events'] as List;
          return events.any((e) => e['action'] != null);
        }
        return false;
      });

      expect(hasEnrichedEvent, isTrue);
    });

    test('should NOT enrich buffered items on cancel', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      faro.startUserAction('test-action');

      // Push telemetry
      faro.pushEvent('buffered-event');
      faro.pushLog('buffered log', level: LogLevel.info);

      // Cancel the action
      await waitForAutoCancellation();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify items were sent WITHOUT action context
      final captured = verify(() => mockTransport.send(captureAny())).captured;
      expect(captured, isNotEmpty);

      // Check that payloads don't have action context
      for (final payload in captured) {
        final map = payload as Map<String, dynamic>;
        if (map['events'] != null && (map['events'] as List).isNotEmpty) {
          final events = map['events'] as List;
          for (final e in events) {
            // Events should NOT have action field
            expect(e['action'], isNull);
          }
        }
      }
    });

    test('should emit user action event on end with correct attributes',
        () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      faro.startUserAction(
        'checkout-flow',
        attributes: {'product': 'premium', 'price': '99.99'},
        options: const StartUserActionOptions(
          importance: UserActionConstants.importanceCritical,
        ),
      );

      // End the action
      await completeActiveAction(source: 'test.user_action_event_on_end');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Find the user action event
      final captured = verify(() => mockTransport.send(captureAny())).captured;
      expect(captured, isNotEmpty);

      var foundUserActionEvent = false;
      for (final payload in captured) {
        final map = payload as Map<String, dynamic>;
        if (map['events'] != null && (map['events'] as List).isNotEmpty) {
          final events = map['events'] as List;
          for (final e in events) {
            if (e['name'] == UserActionConstants.userActionEventName) {
              foundUserActionEvent = true;

              // Verify attributes
              expect(
                  e['attributes']['userActionName'], equals('checkout-flow'));
              expect(
                e['attributes']['userActionImportance'],
                equals(UserActionConstants.importanceCritical),
              );
              expect(e['attributes']['product'], equals('premium'));
              expect(e['attributes']['price'], equals('99.99'));
              expect(e['attributes']['userActionStartTime'], isNotNull);
              expect(e['attributes']['userActionEndTime'], isNotNull);
              expect(e['attributes']['userActionDuration'], isNotNull);
              expect(e['attributes']['userActionTrigger'], isNotNull);
            }
          }
        }
      }

      expect(foundUserActionEvent, isTrue);
    });

    test('should NOT emit user action event on cancel', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      faro.startUserAction('test-action');

      // Cancel the action
      await waitForAutoCancellation();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Check that no user action event was sent
      final captured = verify(() => mockTransport.send(captureAny())).captured;

      var foundUserActionEvent = false;
      for (final payload in captured) {
        final map = payload as Map<String, dynamic>;
        if (map['events'] != null && (map['events'] as List).isNotEmpty) {
          final events = map['events'] as List;
          for (final e in events) {
            if (e['name'] == UserActionConstants.userActionEventName) {
              foundUserActionEvent = true;
            }
          }
        }
      }

      expect(foundUserActionEvent, isFalse);
    });

    test('should support multiple sequential actions', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      // First action
      final action1 = faro.startUserAction('action-1');
      expect(action1, isNotNull);
      faro.pushEvent('event-1');
      await completeActiveAction(source: 'test.sequential_action_1');

      // Second action
      final action2 = faro.startUserAction('action-2');
      expect(action2, isNotNull);
      faro.pushEvent('event-2');
      await completeActiveAction(source: 'test.sequential_action_2');

      // Third action
      final action3 = faro.startUserAction('action-3');
      expect(action3, isNotNull);
      faro.pushEvent('event-3');
      await completeActiveAction(source: 'test.sequential_action_3');

      // Verify all actions completed
      final captured = verify(() => mockTransport.send(captureAny())).captured;
      expect(captured.length, greaterThanOrEqualTo(3));
    });

    test('should handle action with no telemetry', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      faro.startUserAction('empty-action');

      // End without pushing any telemetry
      await completeActiveAction(source: 'test.empty_action');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should still emit the user action event
      final captured = verify(() => mockTransport.send(captureAny())).captured;
      expect(captured, isNotEmpty);

      var foundUserActionEvent = false;
      for (final payload in captured) {
        final map = payload as Map<String, dynamic>;
        if (map['events'] != null && (map['events'] as List).isNotEmpty) {
          final events = map['events'] as List;
          for (final e in events) {
            if (e['name'] == UserActionConstants.userActionEventName) {
              foundUserActionEvent = true;
            }
          }
        }
      }

      expect(foundUserActionEvent, isTrue);
    });

    test('should handle mixed telemetry types in one action', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      faro.startUserAction('mixed-action');

      // Push various telemetry types
      faro.pushEvent('test-event');
      faro.pushLog('test log', level: LogLevel.info);
      faro.pushError(type: 'TestError', value: 'error message');
      faro.pushEvent('another-event');

      await completeActiveAction(source: 'test.mixed_action');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify all types were sent
      final captured = verify(() => mockTransport.send(captureAny())).captured;
      expect(captured, isNotEmpty);

      var hasEvents = false;
      var hasLogs = false;
      var hasExceptions = false;

      for (final payload in captured) {
        final map = payload as Map<String, dynamic>;
        if (map['events'] != null && (map['events'] as List).isNotEmpty) {
          hasEvents = true;
        }
        if (map['logs'] != null && (map['logs'] as List).isNotEmpty) {
          hasLogs = true;
        }
        if (map['exceptions'] != null &&
            (map['exceptions'] as List).isNotEmpty) {
          hasExceptions = true;
        }
      }

      expect(hasEvents, isTrue);
      expect(hasLogs, isTrue);
      expect(hasExceptions, isTrue);
    });

    test('should allow starting new action after previous one ends', () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      // Start and end first action
      final action1 = faro.startUserAction('action-1');
      expect(action1, isNotNull);
      await completeActiveAction(source: 'test.first_action_end');

      // Should be able to start a new action
      final action2 = faro.startUserAction('action-2');
      expect(action2, isNotNull);
      expect(action2!.name, equals('action-2'));

      await completeActiveAction(source: 'test.second_action_end');
    });

    test('should allow starting new action after previous one is cancelled',
        () async {
      // Initialize Faro with required dependencies
      await faro.init(
        optionsConfiguration: FaroConfig(
          collectorUrl: 'https://example.com',
          appName: 'test-app',
          appEnv: 'test',
          apiKey: 'test-key',
          batchConfig: BatchConfig(enabled: false),
        ),
      );

      // Start and cancel first action
      final action1 = faro.startUserAction('action-1');
      expect(action1, isNotNull);
      await waitForAutoCancellation();

      // Should be able to start a new action
      final action2 = faro.startUserAction('action-2');
      expect(action2, isNotNull);
      expect(action2!.name, equals('action-2'));

      await completeActiveAction(source: 'test.after_cancel_end');
    });
  });
}
