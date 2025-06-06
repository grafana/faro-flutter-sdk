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
      final value = _otelReadOnlySpan.attributes.get(key).toString();
      faroEventAttributes[key] = _sanitizeAttributeValue(value);
    }

    // Add span duration in nanoseconds
    final durationString = _getSpanDurationString();
    if (durationString != null) {
      faroEventAttributes['duration_ns'] = durationString;
    }

    return faroEventAttributes;
  }

  String _sanitizeAttributeValue(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  String? _getSpanDurationString() {
    final startTime = _otelReadOnlySpan.startTime;
    final endTime = _otelReadOnlySpan.endTime;
    if (startTime.toInt() > 0 &&
        endTime != null &&
        endTime.toInt() > 0 &&
        endTime >= startTime) {
      return (endTime - startTime).toString();
    }
    return null;
  }

  String getFaroEventName() {
    // Check for HTTP semantic attributes to determine if it's an HTTP span
    final attributes = _otelReadOnlySpan.attributes;
    final httpScheme = attributes.get('http.scheme');
    final httpMethod = attributes.get('http.method');

    final hasHttpScheme =
        httpScheme != null && httpScheme.toString().isNotEmpty;
    final hasHttpMethod =
        httpMethod != null && httpMethod.toString().isNotEmpty;

    if (hasHttpScheme || hasHttpMethod) {
      return 'faro.tracing.fetch';
    } else {
      // Use the original span name prefixed with "span." for non-HTTP spans
      return 'span.${name()}';
    }
  }
}
