import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/models/trace/trace_resource.dart';
import 'package:faro/src/models/trace/trace_scope_spans.dart';
import 'package:faro/src/models/trace/trace_span.dart';
import 'package:faro/src/models/trace/trace_span_status.dart';
import 'package:faro/src/tracing/extensions.dart';
import 'package:fixnum/fixnum.dart';

class SpanRecord {
  SpanRecord({required otel.Span otelReadOnlySpan})
    : _otelReadOnlySpan = otelReadOnlySpan;

  final otel.Span _otelReadOnlySpan;

  String name() {
    return _otelReadOnlySpan.name;
  }

  TraceResource getResource() {
    final attrs = _otelReadOnlySpan.resource?.attributes;
    return TraceResource(attributes: attrs?.toTraceAttributes() ?? const []);
  }

  TraceScope getScope() {
    final scope = _otelReadOnlySpan.instrumentationScope;
    return TraceScope(name: scope.name, version: scope.version ?? '');
  }

  TraceSpan getSpan() {
    final parentSpanContext = _otelReadOnlySpan.parentSpanContext;
    return TraceSpan(
      traceId: _otelReadOnlySpan.spanContext.traceId.toString(),
      spanId: _otelReadOnlySpan.spanContext.spanId.toString(),
      parentSpanId:
          (parentSpanContext != null && parentSpanContext.isValid)
              ? parentSpanContext.spanId.toString()
              : null,
      name: _otelReadOnlySpan.name,
      kind: _otelReadOnlySpan.kind.toCode(),
      startTimeUnixNano: dateTimeToUnixNano(_otelReadOnlySpan.startTime),
      endTimeUnixNano: dateTimeToUnixNano(_otelReadOnlySpan.endTime),
      // ignore: invalid_use_of_visible_for_testing_member
      attributes: _otelReadOnlySpan.attributes.toTraceAttributes(),
      events: _otelReadOnlySpan.spanEvents?.toTraceSpanEventsList() ?? const [],
      droppedEventsCount: 0,
      links: _otelReadOnlySpan.spanLinks?.toTraceSpanLinksList() ?? const [],
      status: TraceSpanStatus(
        code: _otelReadOnlySpan.status.toCode(),
        message: _otelReadOnlySpan.statusDescription,
      ),
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
    // ignore: invalid_use_of_visible_for_testing_member
    for (final attribute in _otelReadOnlySpan.attributes.toList()) {
      final value = attribute.value.toString();
      faroEventAttributes[attribute.key] = _sanitizeAttributeValue(value);
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
    if (endTime == null) return null;
    if (!endTime.isAfter(startTime) && endTime != startTime) return null;
    final startNs = dateTimeToUnixNano(startTime);
    final endNs = dateTimeToUnixNano(endTime);
    if (startNs <= Int64() || endNs <= Int64() || endNs < startNs) {
      return null;
    }
    return (endNs - startNs).toString();
  }

  String getFaroEventName() {
    // ignore: invalid_use_of_visible_for_testing_member
    final attributes = _otelReadOnlySpan.attributes;
    final httpScheme = attributes.getString('http.scheme');
    final httpMethod = attributes.getString('http.method');

    final hasHttpScheme = httpScheme != null && httpScheme.isNotEmpty;
    final hasHttpMethod = httpMethod != null && httpMethod.isNotEmpty;

    if (hasHttpScheme || hasHttpMethod) {
      return 'faro.tracing.fetch';
    } else {
      return 'span.${name()}';
    }
  }
}
