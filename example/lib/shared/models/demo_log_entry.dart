import 'package:equatable/equatable.dart';

/// Visual style used when rendering a demo log entry.
enum DemoLogTone {
  neutral,
  info,
  success,
  warning,
  error,
  highlight,
}

/// A timestamped entry shown in example feature log panels.
class DemoLogEntry extends Equatable {
  const DemoLogEntry({
    required this.message,
    required this.timestamp,
    this.tone = DemoLogTone.neutral,
  });

  final String message;
  final DateTime timestamp;
  final DemoLogTone tone;

  @override
  List<Object?> get props => [message, timestamp, tone];
}
