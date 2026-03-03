import 'dart:async';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/user_actions/user_action_signal.dart';

/// Internal channel for user-action lifecycle signals.
class UserActionLifecycleSignalChannel implements Disposable {
  final StreamController<UserActionSignal> _controller =
      StreamController<UserActionSignal>.broadcast();

  Stream<UserActionSignal> get stream => _controller.stream;

  void emitActivity({
    required String source,
  }) {
    _emit(UserActionSignal.activity(source: source));
  }

  void emitPendingStart({
    required String source,
    required String operationId,
  }) {
    _emit(
      UserActionSignal.pendingStart(
        source: source,
        operationId: operationId,
      ),
    );
  }

  void emitPendingEnd({
    required String source,
    required String operationId,
  }) {
    _emit(
      UserActionSignal.pendingEnd(
        source: source,
        operationId: operationId,
      ),
    );
  }

  void _emit(UserActionSignal signal) {
    _controller.add(signal);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

final userActionLifecycleSignalChannelProvider =
    Provider<UserActionLifecycleSignalChannel>(
  (pod) => UserActionLifecycleSignalChannel(),
);
