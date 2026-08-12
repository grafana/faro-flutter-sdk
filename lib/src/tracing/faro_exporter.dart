import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/models/user_action_context.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';

class FaroExporter implements otel.SpanExporter {
  FaroExporter({required TelemetryRouter telemetryRouter})
    : _telemetryRouter = telemetryRouter;

  final TelemetryRouter _telemetryRouter;
  var _isShutdown = false;

  @override
  Future<void> export(List<otel.Span> spans) async {
    if (_isShutdown) {
      return;
    }
    _sendSpansToFaro(spans);
  }

  @override
  Future<void> forceFlush() async {
    return;
  }

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }

  void _sendSpansToFaro(List<otel.Span> spans) {
    for (final otelSpan in spans) {
      final spanRecord = SpanRecord(otelReadOnlySpan: otelSpan);
      final attributes = spanRecord.getFaroEventAttributes();

      final actionName = attributes[UserActionConstants.actionNameKey];
      final actionParentId = attributes[UserActionConstants.actionParentIdKey];
      final hasTrackedAction = actionName != null && actionParentId != null;
      if (hasTrackedAction) {
        attributes.remove(UserActionConstants.actionNameKey);
        attributes.remove(UserActionConstants.actionParentIdKey);
      }

      final event = Event(
        spanRecord.getFaroEventName(),
        attributes: attributes,
        trace: spanRecord.getFaroSpanContext(),
      );

      if (hasTrackedAction) {
        event.action = UserActionContext(
          name: actionName.toString(),
          parentId: actionParentId.toString(),
        );
      }

      final activity = hasTrackedAction
          ? SessionActivityKind.meaningful
          : SessionActivityKind.passive;
      _telemetryRouter.ingest(
        TelemetryItem.fromEvent(event),
        activity: activity,
        skipBuffer: true,
      );
      _telemetryRouter.ingest(
        TelemetryItem.fromSpan(spanRecord),
        activity: activity,
      );
    }
  }
}

class FaroExporterFactory {
  FaroExporter create() {
    return FaroExporter(telemetryRouter: pod.resolve(telemetryRouterProvider));
  }
}
