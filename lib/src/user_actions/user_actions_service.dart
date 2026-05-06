import 'dart:async';
import 'dart:developer';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/start_user_action_options.dart';
import 'package:faro/src/user_actions/telemetry_item_dispatcher.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:faro/src/user_actions/user_action_controller.dart';
import 'package:faro/src/user_actions/user_action_handle.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:faro/src/user_actions/user_action_types.dart';

/// Internal manager for user actions.
class UserActionsService {
  UserActionsService({
    required BatchTransportResolver transportResolver,
    required UserActionLifecycleControllerFactory lifecycleControllerFactory,
  }) : _transportResolver = transportResolver,
       _lifecycleControllerFactory = lifecycleControllerFactory;

  final BatchTransportResolver _transportResolver;
  final UserActionLifecycleControllerFactory _lifecycleControllerFactory;

  UserAction? _activeUserAction;
  UserActionLifecycleController? _activeController;
  StreamSubscription<UserActionState>? _stateSubscription;

  UserActionHandle? startUserAction(
    String name, {
    Map<String, String>? attributes,
    StartUserActionOptions? options,
  }) {
    if (_activeUserAction != null) {
      log(
        'Faro: Cannot start user action "$name"'
        ' - another action is active',
      );
      return null;
    }

    if (_transportResolver() == null) {
      log(
        'Faro: Cannot start user action'
        ' - Faro not initialized',
      );
      return null;
    }

    final effectiveOptions = options ?? const StartUserActionOptions();

    final userAction = UserAction(
      name: name,
      trigger: effectiveOptions.triggerName,
      attributes: attributes,
      importance: effectiveOptions.importance,
    );

    _activeUserAction = userAction;

    final controller = _lifecycleControllerFactory(userAction);
    _activeController = controller;
    controller.attach();

    _stateSubscription?.cancel();
    _stateSubscription = userAction.stateChanges
        .where(
          (state) =>
              state == UserActionState.ended ||
              state == UserActionState.cancelled,
        )
        .take(1)
        .listen((_) => _onActionTerminated(userAction));

    return userAction;
  }

  void _onActionTerminated(UserAction userAction) {
    if (_activeUserAction != userAction) return;

    _dispatchPendingItems(userAction);
    _releaseActiveAction();
  }

  void _dispatchPendingItems(UserAction userAction) {
    final transport = _transportResolver();
    if (transport == null) return;

    final items = userAction.takePendingItems();
    for (final item in items) {
      TelemetryItemDispatcher.dispatch(item, transport);
    }
  }

  /// Disposes of any active action and releases all resources.
  void dispose() {
    _releaseActiveAction();
  }

  void _releaseActiveAction() {
    _activeController?.dispose();
    _stateSubscription?.cancel();
    _activeUserAction?.dispose();
    _activeUserAction = null;
    _activeController = null;
    _stateSubscription = null;
  }

  UserActionHandle? getActiveUserAction() => _activeUserAction;

  /// Tries to buffer an item into the active action.
  ///
  /// Returns `true` if buffered, `false` if no active action can
  /// accept it.
  bool tryBuffer(TelemetryItem item) {
    final active = _activeUserAction;
    if (active == null || active.getState() != UserActionState.started) {
      return false;
    }
    return active.addItem(item);
  }
}

final userActionsServiceProvider = Provider<UserActionsService>((pod) {
  return UserActionsService(
    transportResolver: pod.resolve(batchTransportResolverProvider),
    lifecycleControllerFactory: pod.resolve(
      userActionLifecycleControllerFactoryProvider,
    ),
  );
});
