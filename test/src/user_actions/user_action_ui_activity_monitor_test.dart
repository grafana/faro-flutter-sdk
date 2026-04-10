import 'package:faro/src/user_actions/user_action_handle.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_signal.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:faro/src/user_actions/user_action_ui_activity_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUserActionHandle implements UserActionHandle {
  _FakeUserActionHandle({required this.id});

  @override
  final String id;

  @override
  final String name = 'test';

  @override
  final String importance = 'high';

  @override
  UserActionState getState() => UserActionState.started;
}

void main() {
  group('UserActionUiActivityMonitor:', () {
    late UserActionLifecycleSignalChannel signalChannel;
    late List<UserActionSignal> emittedSignals;
    late UserActionUiActivityMonitor monitor;
    UserActionHandle? activeAction;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      signalChannel = UserActionLifecycleSignalChannel();
      emittedSignals = <UserActionSignal>[];
      signalChannel.stream.listen(emittedSignals.add);
      activeAction = null;
    });

    tearDown(() {
      monitor.detach();
      signalChannel.dispose();
    });

    testWidgets('does not recurse when another component wraps '
        'onBuildScheduled after attach', (tester) async {
      final binding = TestWidgetsFlutterBinding.instance;
      final buildOwner = binding.buildOwner!;

      monitor = UserActionUiActivityMonitor(
        lifecycleSignalChannel: signalChannel,
        activeUserActionResolver: () => activeAction,
        schedulerBinding: binding,
        widgetsBinding: binding,
      );

      monitor.attach();

      // An external component wraps onBuildScheduled *after* the
      // monitor attached, chaining back to the monitor's callback.
      final monitorCallback = buildOwner.onBuildScheduled;
      var externalCallCount = 0;
      buildOwner.onBuildScheduled = () {
        externalCallCount++;
        monitorCallback?.call();
      };

      activeAction = _FakeUserActionHandle(id: 'action-1');

      // Pump triggers _onPersistentFrame. Before the fix this would
      // re-wrap and store the external wrapper (which chains to us)
      // as _previousOnBuildScheduled.
      await tester.pump();

      // Invoke onBuildScheduled. Before the fix, the callback chain
      // would loop: monitor → external wrapper → monitor → … until
      // a StackOverflowError.
      buildOwner.onBuildScheduled?.call();

      // Reaching here without StackOverflowError means the fix works.
      // The external wrapper should have been called exactly once.
      expect(externalCallCount, 1);

      activeAction = null;
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('preserves external wrapper in the callback chain', (
      tester,
    ) async {
      final binding = TestWidgetsFlutterBinding.instance;
      final buildOwner = binding.buildOwner!;

      monitor = UserActionUiActivityMonitor(
        lifecycleSignalChannel: signalChannel,
        activeUserActionResolver: () => activeAction,
        schedulerBinding: binding,
        widgetsBinding: binding,
      );

      monitor.attach();

      var externalCallCount = 0;
      final monitorCallback = buildOwner.onBuildScheduled;
      buildOwner.onBuildScheduled = () {
        externalCallCount++;
        monitorCallback?.call();
      };

      // Pump several frames — the monitor must not clobber the
      // external wrapper just because the callback identity changed.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      // Trigger the callback chain via the external wrapper.
      buildOwner.onBuildScheduled?.call();

      expect(externalCallCount, 1);
    });
  });
}
