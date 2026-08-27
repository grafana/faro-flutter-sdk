/// Classifies telemetry by how it affects the session inactivity window.
enum SessionActivityKind {
  /// Represents user or application work that extends inactivity.
  meaningful,

  /// Represents telemetry that checks expiry without extending inactivity.
  passive,
}
