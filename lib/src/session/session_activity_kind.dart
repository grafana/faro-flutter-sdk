/// Classifies telemetry by how it affects the session inactivity window.
enum SessionActivityKind {
  /// Always extends the inactivity window.
  active,

  /// Extends the window only while the app is in the foreground.
  foregroundOnly,

  /// Never extends the window (e.g. SDK lifecycle events).
  none,
}
