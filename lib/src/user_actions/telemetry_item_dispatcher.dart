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
    switch (item.type) {
      case TelemetryItemType.event:
        transport.addEvent(item.asEvent!);
        break;
      case TelemetryItemType.log:
        transport.addLog(item.asLog!);
        break;
      case TelemetryItemType.exception:
        transport.addExceptions(item.asException!);
        break;
      case TelemetryItemType.measurement:
        transport.addMeasurement(item.asMeasurement!);
        break;
      case TelemetryItemType.span:
        transport.addSpan(item.asSpan!);
        break;
    }
  }
}
