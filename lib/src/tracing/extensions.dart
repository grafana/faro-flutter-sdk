import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/models/trace/trace_attribute.dart';
import 'package:faro/src/models/trace/trace_span_event.dart';
import 'package:faro/src/models/trace/trace_span_link.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:fixnum/fixnum.dart';

extension TraceAttributesX on otel.Attributes {
  List<TraceAttribute> toTraceAttributes() {
    return toList().map((attribute) {
      return TraceAttribute(
        key: attribute.key,
        value: TraceAttributeValue.fromDynamic(attribute.value),
      );
    }).toList();
  }
}

extension IterableTraceAttributeX on Iterable<otel.Attribute<Object>> {
  List<TraceAttribute> toTraceAttributes() {
    return map((attribute) {
      return TraceAttribute(
        key: attribute.key,
        value: TraceAttributeValue.fromDynamic(attribute.value),
      );
    }).toList();
  }
}

extension SpanKindX on otel.SpanKind {
  int toCode() {
    switch (this) {
      case otel.SpanKind.internal:
        return 1;
      case otel.SpanKind.server:
        return 2;
      case otel.SpanKind.client:
        return 3;
      case otel.SpanKind.producer:
        return 4;
      case otel.SpanKind.consumer:
        return 5;
    }
  }
}

extension OtelSpanStatusCodeX on otel.SpanStatusCode {
  int toCode() {
    switch (this) {
      case otel.SpanStatusCode.Unset:
        return 0;
      case otel.SpanStatusCode.Ok:
        return 1;
      case otel.SpanStatusCode.Error:
        return 2;
    }
  }

  SpanStatusCode toSpanStatusCode() {
    switch (this) {
      case otel.SpanStatusCode.Unset:
        return SpanStatusCode.unset;
      case otel.SpanStatusCode.Ok:
        return SpanStatusCode.ok;
      case otel.SpanStatusCode.Error:
        return SpanStatusCode.error;
    }
  }
}

extension FaroSpanStatusCodeX on SpanStatusCode {
  otel.SpanStatusCode toOtelStatusCode() {
    switch (this) {
      case SpanStatusCode.unset:
        return otel.SpanStatusCode.Unset;
      case SpanStatusCode.error:
        return otel.SpanStatusCode.Error;
      case SpanStatusCode.ok:
        return otel.SpanStatusCode.Ok;
    }
  }
}

extension SpanEventListX on List<otel.SpanEvent> {
  List<TraceSpanEvent> toTraceSpanEventsList() {
    return map((event) {
      return TraceSpanEvent(
        name: event.name,
        timeUnixNano: dateTimeToUnixNano(event.timestamp),
        droppedAttributesCount: 0,
        attributes: event.attributes?.toTraceAttributes() ?? const [],
      );
    }).toList();
  }
}

extension SpanLinkListX on List<otel.SpanLink> {
  List<TraceSpanLink> toTraceSpanLinksList() {
    return map((link) {
      return TraceSpanLink(
        traceId: link.spanContext.traceId.toString(),
        spanId: link.spanContext.spanId.toString(),
        traceState: link.spanContext.traceState?.toString() ?? '',
        attributes: link.attributes.toTraceAttributes(),
      );
    }).toList();
  }
}

/// Converts a [DateTime] to nanoseconds since the Unix epoch.
Int64 dateTimeToUnixNano(DateTime? timestamp) {
  if (timestamp == null) return Int64();
  return Int64(timestamp.microsecondsSinceEpoch) * Int64(1000);
}
