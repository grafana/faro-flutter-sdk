/// Represents the lifecycle state of a user action.
enum UserActionState {
  /// Initial state when a user action is started.
  /// In this state, the action buffers telemetry items.
  started,

  /// Transitioned to when the action has pending async operations
  /// (e.g., HTTP requests). In this state, the action stops buffering
  /// new items and waits for pending operations to complete.
  halted,

  /// Terminal state reached when the action completes normally.
  /// Buffered items are flushed with action context enrichment.
  ended,

  /// Terminal state reached when the action times out or has no activity.
  /// Buffered items are flushed without action context enrichment.
  cancelled,
}
