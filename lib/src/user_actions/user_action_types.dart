import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/models/user_action_context.dart';

/// Type of telemetry item being transported.
enum TelemetryItemType {
  event,
  log,
  exception,
  measurement,
  span,
}

/// Represents a telemetry item that can be buffered during a user action.
class TelemetryItem {
  TelemetryItem({
    required this.type,
    required this.payload,
  });

  /// Creates a telemetry item from a SpanRecord.
  factory TelemetryItem.fromSpan(SpanRecord span) {
    return TelemetryItem(
      type: TelemetryItemType.span,
      payload: span,
    );
  }

  /// Creates a telemetry item from a Measurement.
  factory TelemetryItem.fromMeasurement(Measurement measurement) {
    return TelemetryItem(
      type: TelemetryItemType.measurement,
      payload: measurement,
    );
  }

  /// Creates a telemetry item from a FaroException.
  factory TelemetryItem.fromException(FaroException exception) {
    return TelemetryItem(
      type: TelemetryItemType.exception,
      payload: exception,
    );
  }

  /// Creates a telemetry item from an Event.
  factory TelemetryItem.fromEvent(Event event) {
    return TelemetryItem(
      type: TelemetryItemType.event,
      payload: event,
    );
  }

  /// Creates a telemetry item from a FaroLog.
  factory TelemetryItem.fromLog(FaroLog log) {
    return TelemetryItem(
      type: TelemetryItemType.log,
      payload: log,
    );
  }

  final TelemetryItemType type;
  final dynamic payload;

  /// Gets the payload as an Event.
  Event? get asEvent =>
      type == TelemetryItemType.event ? payload as Event : null;

  /// Gets the payload as a FaroLog.
  FaroLog? get asLog =>
      type == TelemetryItemType.log ? payload as FaroLog : null;

  /// Gets the payload as a FaroException.
  FaroException? get asException =>
      type == TelemetryItemType.exception ? payload as FaroException : null;

  /// Gets the payload as a Measurement.
  Measurement? get asMeasurement =>
      type == TelemetryItemType.measurement ? payload as Measurement : null;

  /// Gets the payload as a SpanRecord.
  SpanRecord? get asSpan =>
      type == TelemetryItemType.span ? payload as SpanRecord : null;

  /// Sets [UserActionContext] on the payload if the item type
  /// supports it (events, logs, exceptions).
  void addUserActionContext(UserActionContext context) {
    asEvent?.action = context;
    asLog?.action = context;
    asException?.action = context;
  }
}
