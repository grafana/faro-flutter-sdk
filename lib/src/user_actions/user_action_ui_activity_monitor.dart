import 'dart:async';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action_handle.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Watches widget build scheduling and emits bounded UI activity signals
/// for active user actions.
///
/// This approximates the Web SDK's DOM mutation signal in Flutter, while
/// deliberately bounding signal emission so ongoing animations do not keep
/// actions alive indefinitely.
class UserActionUiActivityMonitor {
  UserActionUiActivityMonitor({
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
    required UserActionHandle? Function() activeUserActionResolver,
    required SchedulerBinding schedulerBinding,
    required WidgetsBinding widgetsBinding,
  })  : _lifecycleSignalChannel = lifecycleSignalChannel,
        _activeUserActionResolver = activeUserActionResolver,
        _schedulerBinding = schedulerBinding,
        _widgetsBinding = widgetsBinding;

  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;
  final UserActionHandle? Function() _activeUserActionResolver;
  final SchedulerBinding _schedulerBinding;
  final WidgetsBinding _widgetsBinding;

  late final VoidCallback _buildScheduledCallback = _onBuildScheduled;

  bool _isAttached = false;
  bool _isPersistentFrameCallbackInstalled = false;
  bool _hasDirtyBuildScheduled = false;
  bool _uiBurstOpen = false;

  BuildOwner? _buildOwner;
  VoidCallback? _previousOnBuildScheduled;
  Timer? _uiBurstQuietTimer;

  String? _trackedActionId;

  /// Starts monitoring build+frame activity.
  ///
  /// Safe to call multiple times. Does nothing when called from a
  /// background isolate (no widget tree to monitor).
  void attach() {
    if (_isAttached) {
      return;
    }
    if (_widgetsBinding.buildOwner == null) {
      return;
    }
    _isAttached = true;
    _attachBuildScheduledListener();
    _installPersistentFrameCallback();
  }

  /// Stops monitoring and clears in-memory tracking.
  ///
  /// This API is primarily useful for tests.
  @visibleForTesting
  void dispose() {
    _isAttached = false;
    _hasDirtyBuildScheduled = false;
    _resetTrackedActionState();

    final buildOwner = _buildOwner;
    if (buildOwner != null &&
        buildOwner.onBuildScheduled == _buildScheduledCallback) {
      buildOwner.onBuildScheduled = _previousOnBuildScheduled;
    }
    _buildOwner = null;
    _previousOnBuildScheduled = null;
  }

  void _attachBuildScheduledListener() {
    final buildOwner = _widgetsBinding.buildOwner;
    if (buildOwner == null) {
      return;
    }

    if (buildOwner.onBuildScheduled == _buildScheduledCallback) {
      return;
    }

    _buildOwner = buildOwner;
    _previousOnBuildScheduled = buildOwner.onBuildScheduled;
    buildOwner.onBuildScheduled = _buildScheduledCallback;
  }

  void _installPersistentFrameCallback() {
    if (_isPersistentFrameCallbackInstalled) {
      return;
    }
    _isPersistentFrameCallbackInstalled = true;
    _schedulerBinding.addPersistentFrameCallback(_onPersistentFrame);
  }

  void _onBuildScheduled() {
    try {
      _hasDirtyBuildScheduled = true;
      _refreshUiBurstQuietTimerIfActionStarted();
    } finally {
      _previousOnBuildScheduled?.call();
    }
  }

  void _onPersistentFrame(Duration _) {
    if (!_isAttached) {
      return;
    }

    // Re-attach only when the BuildOwner instance itself has changed (e.g.
    // hot restart). Checking the callback identity instead would break if
    // another component wraps onBuildScheduled after us: we'd store the
    // wrapper as _previousOnBuildScheduled while it already chains back to
    // us, creating infinite recursion on the next build.
    if (_widgetsBinding.buildOwner != _buildOwner) {
      _attachBuildScheduledListener();
    }

    if (!_hasDirtyBuildScheduled) {
      return;
    }

    final activeAction = _activeUserActionResolver();
    if (!_syncTrackedAction(activeAction)) {
      _hasDirtyBuildScheduled = false;
      return;
    }

    _refreshUiBurstQuietTimer();

    if (!_uiBurstOpen) {
      _lifecycleSignalChannel.emitActivity(
        source: UserActionConstants.uiActivitySignalSource,
      );
      _uiBurstOpen = true;
    }

    _hasDirtyBuildScheduled = false;
  }

  bool _syncTrackedAction(UserActionHandle? activeAction) {
    if (activeAction == null ||
        activeAction.getState() != UserActionState.started) {
      _resetTrackedActionState();
      return false;
    }

    if (_trackedActionId != activeAction.id) {
      _trackedActionId = activeAction.id;
      _uiBurstOpen = false;
      _uiBurstQuietTimer?.cancel();
    }

    return true;
  }

  void _refreshUiBurstQuietTimerIfActionStarted() {
    final activeAction = _activeUserActionResolver();
    if (!_syncTrackedAction(activeAction)) {
      return;
    }
    _refreshUiBurstQuietTimer();
  }

  void _refreshUiBurstQuietTimer() {
    _uiBurstQuietTimer?.cancel();
    _uiBurstQuietTimer = Timer(
      UserActionConstants.defaultUiActivityBurstQuietPeriod,
      () {
        _uiBurstOpen = false;
      },
    );
  }

  void _resetTrackedActionState() {
    _trackedActionId = null;
    _uiBurstOpen = false;
    _uiBurstQuietTimer?.cancel();
    _uiBurstQuietTimer = null;
  }
}

final userActionUiActivityMonitorProvider =
    Provider<UserActionUiActivityMonitor>((pod) {
  final signalChannel = pod.resolve(userActionLifecycleSignalChannelProvider);
  final userActionsService = pod.resolve(userActionsServiceProvider);
  return UserActionUiActivityMonitor(
    lifecycleSignalChannel: signalChannel,
    activeUserActionResolver: userActionsService.getActiveUserAction,
    schedulerBinding: SchedulerBinding.instance,
    widgetsBinding: WidgetsBinding.instance,
  );
});
