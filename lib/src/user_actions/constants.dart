/// Constants for user actions feature.
class UserActionConstants {
  /// Event name for user action telemetry.
  static const String userActionEventName = 'faro.user.action';

  /// Internal activity signal source used for build/frame-based UI updates.
  static const String uiActivitySignalSource = 'ui.build';

  /// Internal pending-operation source used for asset/resource loading.
  static const String resourceAssetSignalSource = 'resource.asset';

  /// Trigger name for actions started via API call.
  static const String apiCallTrigger = 'faroApiCall';

  /// Normal importance level.
  static const String importanceNormal = 'normal';

  /// Critical importance level.
  static const String importanceCritical = 'critical';

  /// Default follow-up timeout duration (100ms).
  /// This is the debounce period to wait for related activity after
  /// a user interaction.
  static const Duration defaultFollowUpTimeout = Duration(milliseconds: 100);

  /// Quiet period used to close a UI activity burst.
  ///
  /// While UI updates keep happening within this period, only one
  /// `activity(ui.build)` signal is emitted for the burst.
  static const Duration defaultUiActivityBurstQuietPeriod =
      defaultFollowUpTimeout;

  /// Default halt timeout duration (10 seconds).
  /// This is the maximum time to wait for pending async operations
  /// (e.g., HTTP requests) before force-ending the action.
  static const Duration defaultHaltTimeout = Duration(seconds: 10);

  /// Span attribute key for the user action name.
  static const String actionNameKey = 'faro.action.user.name';

  /// Span attribute key for the user action parent ID.
  static const String actionParentIdKey = 'faro.action.user.parentId';

  /// Span attribute key that marks a span as a pending user-action operation.
  ///
  /// When `true`, span lifecycle events are mirrored to user-action pending
  /// signals using the span ID as operation ID.
  static const String pendingOperationKey = 'faro.action.user.pending';
}
