import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:faro/src/user_actions/user_action_controller.dart';
import 'package:faro/src/user_actions/user_action_signal.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<UserActionSignal> signalController;

  setUp(() {
    signalController = StreamController<UserActionSignal>.broadcast();
  });

  tearDown(() {
    signalController.close();
  });

  group('UserActionLifecycleController:', () {
    group('attach and cleanup:', () {
      test('should attach and start monitoring', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          expect(action.getState(), equals(UserActionState.started));

          controller.dispose();
          action.dispose();
        });
      });

      test('should clean up when action ends', () async {
        final action = UserAction(name: 'test-action', trigger: 'test');

        final controller = UserActionLifecycleController(
          action,
          signalController.stream,
        );

        controller.attach();

        action.end();

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(action.getState(), equals(UserActionState.ended));

        controller.dispose();
        action.dispose();
      });

      test('should clean up when action is cancelled', () async {
        final action = UserAction(name: 'test-action', trigger: 'test');

        final controller = UserActionLifecycleController(
          action,
          signalController.stream,
        );

        controller.attach();

        action.cancel();

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(action.getState(), equals(UserActionState.cancelled));

        controller.dispose();
        action.dispose();
      });
    });

    group('follow-up timeout:', () {
      test('should cancel action after follow-up timeout with no activity', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          expect(action.getState(), equals(UserActionState.started));

          async.elapse(UserActionConstants.defaultFollowUpTimeout);

          expect(action.getState(), equals(UserActionState.cancelled));

          controller.dispose();
          action.dispose();
        });
      });

      test('should end action after follow-up timeout with valid activity', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);

          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });

      test('should reset follow-up timeout on new activity', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          async.elapse(const Duration(milliseconds: 50));
          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          async.elapse(const Duration(milliseconds: 50));
          expect(action.getState(), equals(UserActionState.started));

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );
          async.elapse(const Duration(milliseconds: 100));

          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });
    });

    group('halt logic:', () {
      test(
        'should halt action when pending requests exist after follow-up',
        () {
          fakeAsync((async) {
            final action = UserAction(name: 'test-action', trigger: 'test');

            final controller = UserActionLifecycleController(
              action,
              signalController.stream,
            );

            controller.attach();

            signalController.add(
              UserActionSignal.pendingStart(
                source: 'http',
                operationId: 'req1',
              ),
            );

            async.elapse(UserActionConstants.defaultFollowUpTimeout);

            expect(action.getState(), equals(UserActionState.halted));

            controller.dispose();
            action.dispose();
          });
        },
      );

      test('should end action when all requests complete in halted state', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);
          expect(action.getState(), equals(UserActionState.halted));

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          async.flushMicrotasks();
          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });

      test('should handle multiple pending requests', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );
          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req2'),
          );
          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req3'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);
          expect(action.getState(), equals(UserActionState.halted));

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );
          expect(action.getState(), equals(UserActionState.halted));

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req2'),
          );
          expect(action.getState(), equals(UserActionState.halted));

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req3'),
          );
          async.flushMicrotasks();
          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });

      test('should ignore untracked request ends in halted state', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);
          expect(action.getState(), equals(UserActionState.halted));

          signalController.add(
            UserActionSignal.pendingEnd(
              source: 'http',
              operationId: 'req-unknown',
            ),
          );

          expect(action.getState(), equals(UserActionState.halted));

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          async.flushMicrotasks();
          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });
    });

    group('halt timeout:', () {
      test('should end action after halt timeout expires', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);
          expect(action.getState(), equals(UserActionState.halted));

          async.elapse(UserActionConstants.defaultHaltTimeout);

          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });

      test('should not end if requests complete before halt timeout', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);
          expect(action.getState(), equals(UserActionState.halted));

          async.elapse(const Duration(seconds: 5));
          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          async.flushMicrotasks();
          expect(action.getState(), equals(UserActionState.ended));

          async.elapse(const Duration(seconds: 5));
          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });
    });

    group('validity tracking:', () {
      test('should mark action as valid on pending start', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);

          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });

      test('should not mark as valid on pending end alone', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);

          expect(action.getState(), equals(UserActionState.cancelled));

          controller.dispose();
          action.dispose();
        });
      });
    });

    group('edge cases:', () {
      test('should handle rapid request start/end cycles', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          for (var i = 0; i < 5; i++) {
            signalController.add(
              UserActionSignal.pendingStart(
                source: 'http',
                operationId: 'req$i',
              ),
            );
            signalController.add(
              UserActionSignal.pendingEnd(source: 'http', operationId: 'req$i'),
            );
          }

          async.elapse(UserActionConstants.defaultFollowUpTimeout);

          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });

      test('should handle no activity', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          async.elapse(UserActionConstants.defaultFollowUpTimeout);

          expect(action.getState(), equals(UserActionState.cancelled));

          controller.dispose();
          action.dispose();
        });
      });

      test('should not process signals after action ends', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);
          expect(action.getState(), equals(UserActionState.ended));

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req2'),
          );

          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });

      test('should handle interleaved requests', () {
        fakeAsync((async) {
          final action = UserAction(name: 'test-action', trigger: 'test');

          final controller = UserActionLifecycleController(
            action,
            signalController.stream,
          );

          controller.attach();

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req1'),
          );

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req2'),
          );

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req1'),
          );

          signalController.add(
            UserActionSignal.pendingStart(source: 'http', operationId: 'req3'),
          );

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req2'),
          );

          async.elapse(UserActionConstants.defaultFollowUpTimeout);
          expect(action.getState(), equals(UserActionState.halted));

          signalController.add(
            UserActionSignal.pendingEnd(source: 'http', operationId: 'req3'),
          );

          async.flushMicrotasks();
          expect(action.getState(), equals(UserActionState.ended));

          controller.dispose();
          action.dispose();
        });
      });
    });
  });
}
