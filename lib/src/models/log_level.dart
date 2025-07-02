/// Log level enum
enum LogLevel {
  /// Trace level - for very detailed diagnostic information
  trace('trace'),

  /// Debug level - for debugging information
  debug('debug'),

  /// Info level - for informational messages
  info('info'),

  /// Log level - generic log messages (Faro Web SDK compatibility)
  log('log'),

  /// Warning level - for warning messages
  warn('warn'),

  /// Error level - for error messages
  error('error');

  const LogLevel(this.value);

  /// The string value sent to the Faro collector
  final String value;

  /// Convert string to LogLevel enum
  ///
  /// Handles both 'warn' and 'warning' for compatibility
  static LogLevel? fromString(String? level) {
    if (level == null) return null;

    switch (level.toLowerCase()) {
      case 'trace':
        return LogLevel.trace;
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'log':
        return LogLevel.log;
      case 'warn':
      case 'warning': // Handle API spec variant
        return LogLevel.warn;
      case 'error':
        return LogLevel.error;
      default:
        return null;
    }
  }

  @override
  String toString() => value;
}
