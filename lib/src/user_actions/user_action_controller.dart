import 'dart:async';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_signal.dart';
import 'package:faro/src/user_actions/user_action_state.dart';

/// Manages the lifecycle and timeout logic for a [UserAction] based on
/// internal user-action signals.
///
/// The controller listens to two classes of signals:
/// 1. Activity signals (navigation/performance/etc.)
/// 2. Pending operation signals (start/end), such as HTTP requests
///
/// It also manages two timeouts:
/// 1. Follow-up timeout (100ms): Debounces activity to group related work
/// 2. Halt timeout (10s): Maximum time to wait for pending async operations
///
/// Lifecycle:
/// 1. Started → monitors for activity
/// 2. If pending operations after follow-up → Halted
/// 3. Halted → waits for operations to complete or halt timeout
/// 4. Valid activity → Ended (telemetry enriched with action)
/// 5. No activity → Cancelled (telemetry sent without action context)
///
/// The owning [UserActionsService] is responsible for calling [dispose]
/// when the action reaches a terminal state.
class UserActionLifecycleController {
  /// Creates a controller for the given user action.
  ///
  /// - [userAction]: The user action to manage
  /// - [signalStream]: Stream of user action lifecycle signals
  UserActionLifecycleController(
    this._userAction,
    this._signalStream,
  );

  final UserAction _userAction;
  final Stream<UserActionSignal> _signalStream;

  Timer? _followUpTimer;
  Timer? _haltTimer;
  StreamSubscription<UserActionSignal>? _signalSubscription;

  bool _isValid = false;
  final Map<String, UserActionSignal> _runningOperations = {};

  /// Attaches the controller to start monitoring.
  ///
  /// Subscribes to the signal stream and begins tracking the action's
  /// lifecycle. Call [dispose] to release all resources.
  void attach() {
    _signalSubscription?.cancel();
    _signalSubscription = _signalStream
        .where((_) =>
            _userAction.getState() == UserActionState.started ||
            _userAction.getState() == UserActionState.halted)
        .where(_shouldProcessSignal)
        .listen(_handleSignal);

    _scheduleFollowUp();
  }

  /// Releases all resources (timers, subscriptions, request tracking).
  void dispose() {
    _followUpTimer?.cancel();
    _haltTimer?.cancel();
    _signalSubscription?.cancel();
    _runningOperations.clear();
  }

  /// Determines if a signal should be processed based on current state.
  bool _shouldProcessSignal(UserActionSignal signal) {
    if (_userAction.getState() == UserActionState.halted) {
      final operationId = signal.operationId;
      return signal.type == UserActionSignalType.pendingEnd &&
          operationId != null &&
          _runningOperations.containsKey(operationId);
    }
    return true;
  }

  /// Handles a lifecycle signal.
  void _handleSignal(UserActionSignal signal) {
    switch (signal.type) {
      case UserActionSignalType.activity:
        _markValidAndScheduleFollowUp();
        break;
      case UserActionSignalType.pendingStart:
        final operationId = signal.operationId;
        if (operationId != null) {
          _runningOperations[operationId] = signal;
        }
        _markValidAndScheduleFollowUp();
        break;
      case UserActionSignalType.pendingEnd:
        final operationId = signal.operationId;
        if (operationId != null) {
          _runningOperations.remove(operationId);
        }
        if (_userAction.getState() == UserActionState.halted &&
            _runningOperations.isEmpty) {
          _endAction();
        }
        break;
    }
  }

  void _markValidAndScheduleFollowUp() {
    _isValid = true;
    _scheduleFollowUp();
  }

  /// Schedules a follow-up timeout.
  void _scheduleFollowUp() {
    _followUpTimer?.cancel();
    _followUpTimer = Timer(UserActionConstants.defaultFollowUpTimeout, () {
      if (_userAction.getState() == UserActionState.started &&
          _runningOperations.isNotEmpty) {
        _haltAction();
        return;
      }

      if (_isValid) {
        _endAction();
        return;
      }

      _cancelAction();
    });
  }

  /// Transitions the action to halted state and starts halt timeout.
  void _haltAction() {
    if (_userAction.getState() != UserActionState.started) return;
    _userAction.halt();
    _startHaltTimeout();
  }

  /// Starts the halt timeout timer.
  ///
  /// If this timer expires while in halted state, the action will be
  /// force-ended even if there are still pending operations.
  void _startHaltTimeout() {
    _haltTimer?.cancel();
    _haltTimer = Timer(UserActionConstants.defaultHaltTimeout, () {
      if (_userAction.getState() == UserActionState.halted) {
        _endAction();
      }
    });
  }

  void _endAction() {
    _userAction.end();
  }

  void _cancelAction() {
    _userAction.cancel();
  }
}

typedef UserActionLifecycleControllerFactory = UserActionLifecycleController
    Function(UserAction userAction);

final userActionLifecycleControllerFactoryProvider =
    Provider<UserActionLifecycleControllerFactory>((pod) {
  final signalChannel = pod.resolve(userActionLifecycleSignalChannelProvider);
  return (UserAction userAction) {
    return UserActionLifecycleController(userAction, signalChannel.stream);
  };
});
