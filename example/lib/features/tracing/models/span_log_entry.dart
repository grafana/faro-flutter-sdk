import 'package:equatable/equatable.dart';

/// Represents a single log entry in the tracing page log view.
///
/// Each entry contains a message, timestamp, and an optional error flag
/// to indicate if the entry represents an error condition.
class SpanLogEntry extends Equatable {
  const SpanLogEntry({
    required this.message,
    required this.timestamp,
    this.isError = false,
  });

  /// The log message to display.
  final String message;

  /// When this log entry was created.
  final DateTime timestamp;

  /// Whether this entry represents an error condition.
  final bool isError;

  @override
  List<Object?> get props => [message, timestamp, isError];
}
