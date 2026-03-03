import 'dart:async';

import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/user_action_context.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action_handle.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/util/short_id.dart';

/// Represents a user action with lifecycle management and telemetry
/// buffering.
///
/// A user action tracks a user interaction (e.g., button click, page
/// navigation) and buffers telemetry (logs, events, exceptions) during
/// the action's lifetime.
///
/// When the action ends, buffered items are enriched with action
/// context and made available via [takePendingItems]. When cancelled,
/// items are made available without enrichment.
///
/// The owning [UserActionsService] is responsible for dispatching the
/// pending items to the transport layer.
class UserAction implements UserActionHandle {
  /// Creates a new user action.
  ///
  /// - [name]: Human-readable name (e.g., "checkout-button")
  /// - [attributes]: Optional custom attributes
  /// - [trigger]: How the action was initiated (e.g., "pointerdown")
  /// - [importance]: "normal" or "critical" (default: "normal")
  UserAction({
    required this.name,
    this.attributes,
    this.trigger = UserActionConstants.apiCallTrigger,
    this.importance = UserActionConstants.importanceNormal,
  })  : id = generateShortId(),
        startTime = DateTime.now().millisecondsSinceEpoch,
        _state = UserActionState.started,
        _stateController = StreamController<UserActionState>.broadcast();

  /// Unique identifier for this action (8-character short ID).
  @override
  final String id;

  /// Human-readable action name.
  @override
  final String name;

  /// How the action was initiated (e.g., "pointerdown",
  /// "faroApiCall").
  final String trigger;

  /// Importance level: "normal" or "critical".
  @override
  final String importance;

  /// Optional custom attributes.
  final Map<String, String>? attributes;

  /// Unix timestamp (milliseconds) when the action started.
  final int startTime;

  UserActionState _state;
  final List<TelemetryItem> _buffer = [];
  final StreamController<UserActionState> _stateController;
  List<TelemetryItem> _pendingItems = [];

  /// Stream that emits when the action state changes.
  Stream<UserActionState> get stateChanges => _stateController.stream;

  /// Gets the current state of the action.
  @override
  UserActionState getState() => _state;

  /// Adds a telemetry item to the buffer.
  ///
  /// Items are only buffered in [UserActionState.started] state.
  /// Returns `true` if the item was buffered, `false` otherwise.
  bool addItem(TelemetryItem item) {
    if (_state == UserActionState.started) {
      _buffer.add(item);
      return true;
    }
    return false;
  }

  /// Drains items ready for dispatch after [end] or [cancel].
  ///
  /// Returns the list once — subsequent calls return an empty list.
  List<TelemetryItem> takePendingItems() {
    final items = _pendingItems;
    _pendingItems = [];
    return items;
  }

  /// Transitions the action to [UserActionState.halted] state.
  ///
  /// Called when the action has pending async operations (e.g., HTTP
  /// requests) and needs to wait for them to complete. In halted
  /// state, new items are no longer buffered.
  void halt() {
    if (_state != UserActionState.started) return;
    _state = UserActionState.halted;
    _stateController.add(_state);
  }

  /// Transitions the action to [UserActionState.cancelled] state.
  ///
  /// Called when the action times out or has no meaningful activity.
  /// Buffered items are drained WITHOUT action context enrichment.
  void cancel() {
    if (_state == UserActionState.ended ||
        _state == UserActionState.cancelled) {
      return;
    }

    _pendingItems = List.of(_buffer);
    _buffer.clear();
    _state = UserActionState.cancelled;
    _stateController.add(_state);
  }

  /// Transitions the action to [UserActionState.ended] state.
  ///
  /// Called when the action completes successfully. Buffered items
  /// are enriched with action context, and a final user action
  /// summary event is appended.
  void end() {
    if (_state == UserActionState.cancelled ||
        _state == UserActionState.ended) {
      return;
    }

    final pendingItemsContext = UserActionContext(name: name, parentId: id);
    for (final item in _buffer) {
      item.addUserActionContext(pendingItemsContext);
    }
    _pendingItems = [..._buffer, _buildSummaryEvent()];
    _buffer.clear();
    _state = UserActionState.ended;
    _stateController.add(_state);
  }

  /// Disposes resources used by the action.
  void dispose() {
    _stateController.close();
  }

  /// Builds the `faro.user.action` summary event emitted when
  /// the action ends successfully.
  TelemetryItem _buildSummaryEvent() {
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final duration = endTime - startTime;

    final event = Event(
      UserActionConstants.userActionEventName,
      attributes: {
        'userActionName': name,
        'userActionStartTime': startTime.toString(),
        'userActionEndTime': endTime.toString(),
        'userActionDuration': duration.toString(),
        'userActionTrigger': trigger,
        'userActionImportance': importance,
        if (attributes != null) ...attributes!,
      },
    );
    event.action = UserActionContext(name: name, id: id);
    return TelemetryItem.fromEvent(event);
  }
}
