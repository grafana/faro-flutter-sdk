import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/user_action_types.dart';

/// Dispatches a [TelemetryItem] to the appropriate method on
/// [BatchTransport].
///
/// This is the single place that maps telemetry item types to
/// transport calls, used by both [TelemetryRouter] and
/// [UserActionsService].
class TelemetryItemDispatcher {
  const TelemetryItemDispatcher._();

  /// Sends [item] to [transport] via the matching typed method.
  static void dispatch(TelemetryItem item, BatchTransport transport) {
    final capture = item.deviceState;
    switch (item.type) {
      case TelemetryItemType.event:
        capture == null
            ? transport.addEvent(item.asEvent!)
            : transport.addEvent(item.asEvent!, capture: capture);
        break;
      case TelemetryItemType.log:
        capture == null
            ? transport.addLog(item.asLog!)
            : transport.addLog(item.asLog!, capture: capture);
        break;
      case TelemetryItemType.exception:
        capture == null
            ? transport.addExceptions(item.asException!)
            : transport.addExceptions(item.asException!, capture: capture);
        break;
      case TelemetryItemType.measurement:
        capture == null
            ? transport.addMeasurement(item.asMeasurement!)
            : transport.addMeasurement(item.asMeasurement!, capture: capture);
        break;
      case TelemetryItemType.span:
        capture == null
            ? transport.addSpan(item.asSpan!)
            : transport.addSpan(item.asSpan!, capture: capture);
        break;
    }
  }
}
