// ignore_for_file: sort_constructors_first

/// Types of lifecycle signals that can affect user action validity/lifecycle.
enum UserActionSignalType {
  /// A meaningful effect related to the action happened (e.g. navigation).
  activity,

  /// A tracked async operation started (e.g. HTTP request start).
  pendingStart,

  /// A tracked async operation ended (e.g. HTTP request end).
  pendingEnd,
}

/// Internal signal used by the user action lifecycle controller.
class UserActionSignal {
  const UserActionSignal._({
    required this.type,
    required this.source,
    this.operationId,
  });

  /// Signal category.
  final UserActionSignalType type;

  /// Source tag for debugging/routing decisions (e.g. "http").
  final String source;

  /// Operation identifier for pending operation tracking.
  ///
  /// Required for [UserActionSignalType.pendingStart] and
  /// [UserActionSignalType.pendingEnd] signals.
  final String? operationId;

  /// Creates an activity signal.
  factory UserActionSignal.activity({
    required String source,
  }) {
    return UserActionSignal._(
      type: UserActionSignalType.activity,
      source: source,
    );
  }

  /// Creates a pending-start signal.
  factory UserActionSignal.pendingStart({
    required String source,
    required String operationId,
  }) {
    return UserActionSignal._(
      type: UserActionSignalType.pendingStart,
      source: source,
      operationId: operationId,
    );
  }

  /// Creates a pending-end signal.
  factory UserActionSignal.pendingEnd({
    required String source,
    required String operationId,
  }) {
    return UserActionSignal._(
      type: UserActionSignalType.pendingEnd,
      source: source,
      operationId: operationId,
    );
  }
}
