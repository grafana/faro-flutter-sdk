// ignore_for_file: avoid_redundant_argument_values

import 'package:faro/src/models/models.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserAction:', () {
    group('initialization:', () {
      test('should initialize with correct default values', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'pointerdown',
        );

        expect(action.name, equals('test-action'));
        expect(action.trigger, equals('pointerdown'));
        expect(action.id, isNotEmpty);
        expect(action.id.length, equals(10));
        expect(
          action.importance,
          equals(UserActionConstants.importanceNormal),
        );
        expect(action.attributes, isNull);
        expect(action.getState(), equals(UserActionState.started));
        expect(action.startTime, greaterThan(0));

        action.dispose();
      });

      test('should initialize with custom attributes', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'keydown',
          attributes: {'key1': 'value1', 'key2': 'value2'},
        );

        expect(action.attributes, isNotNull);
        expect(action.attributes!['key1'], equals('value1'));
        expect(action.attributes!['key2'], equals('value2'));

        action.dispose();
      });

      test('should initialize with critical importance', () {
        final action = UserAction(
          name: 'test-action',
          trigger: UserActionConstants.apiCallTrigger,
          importance: UserActionConstants.importanceCritical,
        );

        expect(
          action.importance,
          equals(UserActionConstants.importanceCritical),
        );

        action.dispose();
      });

      test('should generate unique IDs for different instances', () {
        final action1 = UserAction(
          name: 'action1',
          trigger: 'test',
        );

        final action2 = UserAction(
          name: 'action2',
          trigger: 'test',
        );

        final action3 = UserAction(
          name: 'action3',
          trigger: 'test',
        );

        expect(action1.id, isNot(equals(action2.id)));
        expect(action1.id, isNot(equals(action3.id)));
        expect(action2.id, isNot(equals(action3.id)));

        action1.dispose();
        action2.dispose();
        action3.dispose();
      });
    });

    group('state machine:', () {
      test('should start in started state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        expect(action.getState(), equals(UserActionState.started));

        action.dispose();
      });

      test('should transition from started to halted', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.halt();

        expect(action.getState(), equals(UserActionState.halted));

        action.dispose();
      });

      test('should not transition to halted if not in started state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.end();
        expect(action.getState(), equals(UserActionState.ended));

        action.halt();
        expect(action.getState(), equals(UserActionState.ended));

        action.dispose();
      });

      test('should transition from started to cancelled', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.cancel();

        expect(
          action.getState(),
          equals(UserActionState.cancelled),
        );

        action.dispose();
      });

      test('should transition from halted to cancelled', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.halt();
        action.cancel();

        expect(
          action.getState(),
          equals(UserActionState.cancelled),
        );

        action.dispose();
      });

      test('should not transition to cancelled if already ended', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.end();
        expect(action.getState(), equals(UserActionState.ended));

        action.cancel();
        expect(action.getState(), equals(UserActionState.ended));

        action.dispose();
      });

      test('should transition from started to ended', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.end();

        expect(action.getState(), equals(UserActionState.ended));

        action.dispose();
      });

      test('should transition from halted to ended', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.halt();
        action.end();

        expect(action.getState(), equals(UserActionState.ended));

        action.dispose();
      });

      test('should not transition to ended if already cancelled', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.cancel();
        expect(
          action.getState(),
          equals(UserActionState.cancelled),
        );

        action.end();
        expect(
          action.getState(),
          equals(UserActionState.cancelled),
        );

        action.dispose();
      });
    });

    group('state change notifications:', () {
      test('should emit state changes on stateChanges stream', () async {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final states = <UserActionState>[];
        final subscription = action.stateChanges.listen(states.add);

        action.halt();
        action.end();

        await Future<void>.delayed(Duration.zero);

        expect(
          states,
          equals([UserActionState.halted, UserActionState.ended]),
        );

        await subscription.cancel();
        action.dispose();
      });

      test('should emit cancelled state on cancel', () async {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final states = <UserActionState>[];
        final subscription = action.stateChanges.listen(states.add);

        action.cancel();

        await Future<void>.delayed(Duration.zero);

        expect(states, equals([UserActionState.cancelled]));

        await subscription.cancel();
        action.dispose();
      });

      test('should support multiple subscribers', () async {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final states1 = <UserActionState>[];
        final states2 = <UserActionState>[];
        final subscription1 = action.stateChanges.listen(states1.add);
        final subscription2 = action.stateChanges.listen(states2.add);

        action.halt();

        await Future<void>.delayed(Duration.zero);

        expect(states1, equals([UserActionState.halted]));
        expect(states2, equals([UserActionState.halted]));

        await subscription1.cancel();
        await subscription2.cancel();
        action.dispose();
      });
    });

    group('item buffering:', () {
      test('should buffer event in started state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final event = Event('test-event');
        final item = TelemetryItem.fromEvent(event);

        final result = action.addItem(item);

        expect(result, isTrue);

        action.dispose();
      });

      test('should buffer log in started state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final log = FaroLog('test log');
        final item = TelemetryItem.fromLog(log);

        final result = action.addItem(item);

        expect(result, isTrue);

        action.dispose();
      });

      test('should buffer exception in started state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final exception = FaroException('TestException', 'test', {});
        final item = TelemetryItem.fromException(exception);

        final result = action.addItem(item);

        expect(result, isTrue);

        action.dispose();
      });

      test('should not buffer in halted state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.halt();

        final event = Event('test-event');
        final item = TelemetryItem.fromEvent(event);

        final result = action.addItem(item);

        expect(result, isFalse);

        action.dispose();
      });

      test('should not buffer in ended state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.end();

        final event = Event('test-event');
        final item = TelemetryItem.fromEvent(event);

        final result = action.addItem(item);

        expect(result, isFalse);

        action.dispose();
      });

      test('should not buffer in cancelled state', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.cancel();

        final event = Event('test-event');
        final item = TelemetryItem.fromEvent(event);

        final result = action.addItem(item);

        expect(result, isFalse);

        action.dispose();
      });

      test('should buffer multiple items', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final event1 = Event('event1');
        final event2 = Event('event2');
        final log = FaroLog('test log');

        action.addItem(TelemetryItem.fromEvent(event1));
        action.addItem(TelemetryItem.fromEvent(event2));
        action.addItem(TelemetryItem.fromLog(log));

        action.end();

        // 3 buffered items + 1 summary event
        final items = action.takePendingItems();
        expect(items.length, equals(4));

        action.dispose();
      });
    });

    group('cancel behavior:', () {
      test(
          'should make buffered items available without enrichment'
          ' on cancel', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final event = Event('test-event');
        final log = FaroLog('test log');

        action.addItem(TelemetryItem.fromEvent(event));
        action.addItem(TelemetryItem.fromLog(log));

        action.cancel();

        final items = action.takePendingItems();
        expect(items.length, equals(2));

        final sentEvent = items[0].asEvent!;
        final sentLog = items[1].asLog!;

        expect(sentEvent.action, isNull);
        expect(sentLog.action, isNull);

        action.dispose();
      });

      test(
          'should not produce pending items multiple times if'
          ' cancelled twice', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final event = Event('test-event');
        action.addItem(TelemetryItem.fromEvent(event));

        action.cancel();
        final items = action.takePendingItems();
        expect(items.length, equals(1));

        // Second cancel is a no-op
        action.cancel();
        final items2 = action.takePendingItems();
        expect(items2, isEmpty);

        action.dispose();
      });

      test('should handle empty buffer on cancel', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.cancel();

        final items = action.takePendingItems();
        expect(items, isEmpty);

        action.dispose();
      });
    });

    group('end behavior:', () {
      test(
          'should make buffered items available with enrichment'
          ' on end', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final event = Event('test-event');
        final log = FaroLog('test log');

        action.addItem(TelemetryItem.fromEvent(event));
        action.addItem(TelemetryItem.fromLog(log));

        action.end();

        final items = action.takePendingItems();
        // 2 buffered + 1 summary event
        expect(items.length, equals(3));

        final sentEvent = items[0].asEvent!;
        final sentLog = items[1].asLog!;

        expect(sentEvent.action, isNotNull);
        expect(sentEvent.action!.parentId, equals(action.id));
        expect(sentEvent.action!.name, equals('test-action'));

        expect(sentLog.action, isNotNull);
        expect(sentLog.action!.parentId, equals(action.id));
        expect(sentLog.action!.name, equals('test-action'));

        action.dispose();
      });

      test('should emit final user action event on end', () {
        final action = UserAction(
          name: 'checkout-flow',
          trigger: 'pointerdown',
          importance: UserActionConstants.importanceCritical,
          attributes: {'product': 'premium'},
        );

        action.end();

        final items = action.takePendingItems();

        // Only the summary event (no buffered items)
        expect(items.length, equals(1));

        final actionEvent = items[0].asEvent!;

        expect(
          actionEvent.name,
          equals(UserActionConstants.userActionEventName),
        );
        expect(
          actionEvent.attributes!['userActionName'],
          equals('checkout-flow'),
        );
        expect(
          actionEvent.attributes!['userActionTrigger'],
          equals('pointerdown'),
        );
        expect(
          actionEvent.attributes!['userActionImportance'],
          equals(UserActionConstants.importanceCritical),
        );
        expect(
          actionEvent.attributes!['product'],
          equals('premium'),
        );
        expect(
          actionEvent.attributes!['userActionStartTime'],
          isNotNull,
        );
        expect(
          actionEvent.attributes!['userActionEndTime'],
          isNotNull,
        );
        expect(
          actionEvent.attributes!['userActionDuration'],
          isNotNull,
        );

        expect(actionEvent.action, isNotNull);
        expect(actionEvent.action!.id, equals(action.id));
        expect(actionEvent.action!.name, equals('checkout-flow'));

        action.dispose();
      });

      test('should calculate duration correctly', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final startTime = action.startTime;

        action.end();

        final items = action.takePendingItems();
        final actionEvent = items.last.asEvent!;

        final duration = int.parse(
          actionEvent.attributes!['userActionDuration'] as String,
        );
        final endTime = int.parse(
          actionEvent.attributes!['userActionEndTime'] as String,
        );

        expect(duration, greaterThanOrEqualTo(0));
        expect(endTime, greaterThanOrEqualTo(startTime));
        expect(endTime - startTime, equals(duration));

        action.dispose();
      });

      test('should handle empty buffer on end', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.end();

        final items = action.takePendingItems();
        // Only the summary event
        expect(items.length, equals(1));
        expect(items[0].type, equals(TelemetryItemType.event));
        expect(
          items[0].asEvent!.name,
          equals(UserActionConstants.userActionEventName),
        );

        action.dispose();
      });

      test('should handle all telemetry types', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final event = Event('test-event');
        final log = FaroLog('test log');
        final exception = FaroException('TestException', 'test', {});
        final measurement = Measurement({'value': 42}, 'test');

        action.addItem(TelemetryItem.fromEvent(event));
        action.addItem(TelemetryItem.fromLog(log));
        action.addItem(TelemetryItem.fromException(exception));
        action.addItem(TelemetryItem.fromMeasurement(measurement));

        action.end();

        final items = action.takePendingItems();
        // 4 buffered + 1 summary event
        expect(items.length, equals(5));

        // Verify types
        expect(items[0].type, equals(TelemetryItemType.event));
        expect(items[1].type, equals(TelemetryItemType.log));
        expect(items[2].type, equals(TelemetryItemType.exception));
        expect(
          items[3].type,
          equals(TelemetryItemType.measurement),
        );
        expect(items[4].type, equals(TelemetryItemType.event));

        action.dispose();
      });

      test('should not enrich measurements with action context', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final measurement = Measurement({'value': 42}, 'test');
        action.addItem(TelemetryItem.fromMeasurement(measurement));

        action.end();

        final items = action.takePendingItems();
        // measurement + summary event
        expect(items.length, equals(2));

        final sentMeasurement = items[0].asMeasurement!;
        expect(sentMeasurement, equals(measurement));

        action.dispose();
      });
    });

    group('takePendingItems:', () {
      test('should return empty list when called before end/cancel', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final items = action.takePendingItems();
        expect(items, isEmpty);

        action.dispose();
      });

      test('should return empty list on second call', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.addItem(TelemetryItem.fromEvent(Event('e1')));
        action.end();

        final first = action.takePendingItems();
        expect(first, isNotEmpty);

        final second = action.takePendingItems();
        expect(second, isEmpty);

        action.dispose();
      });
    });

    group('dispose:', () {
      test('should close state controller on dispose', () async {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final states = <UserActionState>[];
        final subscription = action.stateChanges.listen(states.add);

        action.dispose();

        await subscription.cancel();
      });

      test('should not crash if disposed multiple times', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        expect(() {
          action.dispose();
          action.dispose();
        }, returnsNormally);
      });
    });

    group('edge cases:', () {
      test('should handle actions with no buffered items', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.halt();
        action.end();

        final items = action.takePendingItems();
        // Only summary event
        expect(items.length, equals(1));
        expect(
          items[0].asEvent!.name,
          equals(UserActionConstants.userActionEventName),
        );

        action.dispose();
      });

      test('should handle rapid state transitions', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        action.halt();
        action.halt(); // No-op
        action.end();
        action.end(); // No-op

        expect(action.getState(), equals(UserActionState.ended));

        action.dispose();
      });

      test('should preserve item order during flush', () {
        final action = UserAction(
          name: 'test-action',
          trigger: 'test',
        );

        final log1 = FaroLog('log 1');
        final log2 = FaroLog('log 2');
        final log3 = FaroLog('log 3');

        action.addItem(TelemetryItem.fromLog(log1));
        action.addItem(TelemetryItem.fromLog(log2));
        action.addItem(TelemetryItem.fromLog(log3));

        action.end();

        final items = action.takePendingItems();
        // 3 logs + 1 summary event
        expect(items.length, equals(4));

        expect(
          (items[0].asLog!).message,
          equals('log 1'),
        );
        expect(
          (items[1].asLog!).message,
          equals('log 2'),
        );
        expect(
          (items[2].asLog!).message,
          equals('log 3'),
        );

        action.dispose();
      });
    });
  });
}
