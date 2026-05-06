/// Action context attached to telemetry items captured during a user action.
///
/// Mirrors the Faro Web SDK `UserAction` type used on transport payloads.
class UserActionContext {
  /// Creates an action context for enriching telemetry items.
  const UserActionContext({required this.name, this.id, this.parentId});

  /// Creates an action context from a JSON map.
  factory UserActionContext.fromJson(Map<String, dynamic> json) {
    return UserActionContext(
      name: json['name'] as String,
      id: json['id'] as String?,
      parentId: json['parentId'] as String?,
    );
  }

  /// The user action name.
  final String name;

  /// The action's own ID.
  ///
  /// Set on the `faro.user.action` summary event to identify the action.
  /// Mutually exclusive with [parentId] in current usage.
  final String? id;

  /// The ID of the action this telemetry belongs to.
  ///
  /// Set on logs, events, and exceptions captured during an action's
  /// lifetime to link them back to the action.
  /// Mutually exclusive with [id] in current usage.
  final String? parentId;

  /// Serializes this context to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (id != null) 'id': id,
      if (parentId != null) 'parentId': parentId,
    };
  }
}
