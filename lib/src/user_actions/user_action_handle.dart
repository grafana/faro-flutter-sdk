import 'package:faro/src/user_actions/user_action_state.dart';

/// A handle to a user action started via [Faro.startUserAction].
///
/// Use this to inspect the action's identity and current state.
/// The action's lifecycle (timeout, end, cancel) is managed
/// automatically by the SDK.
abstract interface class UserActionHandle {
  /// Unique identifier for this action.
  String get id;

  /// Human-readable action name.
  String get name;

  /// Importance level of this action.
  String get importance;

  /// Current state of this action.
  UserActionState getState();
}
