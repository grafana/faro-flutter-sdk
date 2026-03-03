import 'package:equatable/equatable.dart';

/// A log entry displayed in the User Actions demo page.
class ActionLogEntry extends Equatable {
  const ActionLogEntry({
    required this.message,
    required this.timestamp,
    this.isError = false,
    this.isHighlight = false,
  });

  final String message;
  final DateTime timestamp;
  final bool isError;

  /// Visually emphasized entries (e.g. state transitions).
  final bool isHighlight;

  @override
  List<Object?> get props => [message, timestamp, isError, isHighlight];
}
