import 'package:faro/src/core/pod.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/models/user_action_context.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class FaroExporter implements otel_sdk.SpanExporter {
  FaroExporter({required TelemetryRouter telemetryRouter})
      : _telemetryRouter = telemetryRouter;

  final TelemetryRouter _telemetryRouter;
  var _isShutdown = false;

  @override
  void export(List<otel_sdk.ReadOnlySpan> spans) {
    if (_isShutdown) {
      return;
    }
    _sendSpansToFaro(spans);
  }

  @override
  void forceFlush() {
    return;
  }

  @override
  void shutdown() {
    _isShutdown = true;
  }

  void _sendSpansToFaro(List<otel_sdk.ReadOnlySpan> spans) {
    for (final otelReadOnlySpan in spans) {
      final spanRecord = SpanRecord(otelReadOnlySpan: otelReadOnlySpan);
      final attributes = spanRecord.getFaroEventAttributes();

      final actionName = attributes[UserActionConstants.actionNameKey];
      final actionParentId = attributes[UserActionConstants.actionParentIdKey];
      if (actionName != null && actionParentId != null) {
        attributes.remove(UserActionConstants.actionNameKey);
        attributes.remove(UserActionConstants.actionParentIdKey);
      }

      final event = Event(
        spanRecord.getFaroEventName(),
        attributes: attributes,
        trace: spanRecord.getFaroSpanContext(),
      );

      if (actionName != null && actionParentId != null) {
        event.action = UserActionContext(
          name: actionName.toString(),
          parentId: actionParentId.toString(),
        );
      }

      _telemetryRouter.ingest(
        TelemetryItem.fromEvent(event),
        skipBuffer: true,
      );
      _telemetryRouter.ingest(TelemetryItem.fromSpan(spanRecord));
    }
  }
}

class FaroExporterFactory {
  FaroExporter create() {
    return FaroExporter(
      telemetryRouter: pod.resolve(telemetryRouterProvider),
    );
  }
}
