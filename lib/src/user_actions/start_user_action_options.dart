import 'package:faro/src/user_actions/constants.dart';

/// Optional configuration for starting a user action.
class StartUserActionOptions {
  /// Creates start options for a user action.
  ///
  /// [triggerName] describes how the action started (for example:
  /// `pointerdown`, `keydown`, or a custom source). Defaults to
  /// [UserActionConstants.apiCallTrigger].
  ///
  /// [importance] should be either
  /// [UserActionConstants.importanceNormal] or
  /// [UserActionConstants.importanceCritical].
  const StartUserActionOptions({
    this.triggerName = UserActionConstants.apiCallTrigger,
    this.importance = UserActionConstants.importanceNormal,
  });

  /// How the action was initiated.
  final String triggerName;

  /// Importance level for the action.
  final String importance;
}
