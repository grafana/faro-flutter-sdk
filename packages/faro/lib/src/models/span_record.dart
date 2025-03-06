import 'package:faro/src/models/trace/trace_resource.dart';
import 'package:faro/src/models/trace/trace_scope_spans.dart';
import 'package:faro/src/models/trace/trace_span.dart';
import 'package:faro/src/tracing/extensions.dart';
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class SpanRecord {
  SpanRecord({
    required otel_sdk.ReadOnlySpan otelReadOnlySpan,
  }) : _otelReadOnlySpan = otelReadOnlySpan;

  final otel_sdk.ReadOnlySpan _otelReadOnlySpan;

  String name() {
    return _otelReadOnlySpan.name;
  }

  TraceResource getResource() {
    return TraceResource(
      attributes: _otelReadOnlySpan.resource.attributes.toTraceAttributes(),
    );
  }

  TraceScope getScope() {
    return TraceScope(
      name: _otelReadOnlySpan.instrumentationScope.name,
      version: _otelReadOnlySpan.instrumentationScope.version,
    );
  }

  TraceSpan getSpan() {
    final parentSpanId = _otelReadOnlySpan.parentSpanId;
    return TraceSpan(
      traceId: _otelReadOnlySpan.spanContext.traceId.toString(),
      spanId: _otelReadOnlySpan.spanContext.spanId.toString(),
      parentSpanId: parentSpanId.isValid ? parentSpanId.toString() : null,
      name: _otelReadOnlySpan.name,
      kind: _otelReadOnlySpan.kind.toCode(),
      startTimeUnixNano: _otelReadOnlySpan.startTime,
      endTimeUnixNano: _otelReadOnlySpan.endTime,
      attributes: _otelReadOnlySpan.attributes.toTraceAttributes(),
      events: _otelReadOnlySpan.events.toTraceSpanEventsList(),
      droppedEventsCount: _otelReadOnlySpan.droppedEventsCount,
      links: _otelReadOnlySpan.links.toTraceSpanLinksList(),
      status: _otelReadOnlySpan.status.toTraceSpanStatus,
    );
  }

  Map<String, String> getFaroSpanContext() {
    return {
      'trace_id': _otelReadOnlySpan.spanContext.traceId.toString(),
      'span_id': _otelReadOnlySpan.spanContext.spanId.toString(),
    };
  }

  Map<String, String> getFaroEventAttributes() {
    final faroEventAttributes = <String, String>{};
    for (final key in _otelReadOnlySpan.attributes.keys) {
      faroEventAttributes[key] =
          _otelReadOnlySpan.attributes.get(key).toString();
    }
    return faroEventAttributes;
  }
}
