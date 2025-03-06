import 'package:faro/src/models/trace/trace_attribute.dart';
import 'package:faro/src/models/trace/trace_span_event.dart';
import 'package:faro/src/models/trace/trace_span_link.dart';
import 'package:faro/src/models/trace/trace_span_status.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

extension TraceAttributesX on otel_sdk.Attributes {
  List<TraceAttribute> toTraceAttributes() {
    final attributes = <TraceAttribute>[];
    for (final key in keys) {
      attributes.add(
        TraceAttribute(
          key: key,
          value: TraceAttributeValue(
            stringValue: get(key).toString(),
          ),
        ),
      );
    }
    return attributes;
  }
}

extension IterableTraceAttributeX on Iterable<otel_api.Attribute> {
  List<TraceAttribute> toTraceAttributes() {
    final traceAttributes = <TraceAttribute>[];
    for (final attribute in this) {
      traceAttributes.add(
        TraceAttribute(
          key: attribute.key,
          value: TraceAttributeValue(
            stringValue: attribute.value.toString(),
          ),
        ),
      );
    }
    return traceAttributes;
  }
}

extension SpanKindX on otel_api.SpanKind {
  int toCode() {
    switch (this) {
      case otel_api.SpanKind.internal:
        return 1;
      case otel_api.SpanKind.server:
        return 2;
      case otel_api.SpanKind.client:
        return 3;
      case otel_api.SpanKind.producer:
        return 4;
      case otel_api.SpanKind.consumer:
        return 5;
    }
  }
}

extension SpanStatusX on otel_api.SpanStatus {
  TraceSpanStatus get toTraceSpanStatus {
    return TraceSpanStatus(
      code: code.toCode(),
      message: description.isNotEmpty ? description : null,
    );
  }
}

extension StatusCodeX on otel_api.StatusCode {
  int toCode() {
    switch (this) {
      case otel_api.StatusCode.unset:
        return 0;
      case otel_api.StatusCode.ok:
        return 1;
      case otel_api.StatusCode.error:
        return 2;
    }
  }
}

extension SpanEventListX on List<otel_api.SpanEvent> {
  List<TraceSpanEvent> toTraceSpanEventsList() {
    final events = <TraceSpanEvent>[];
    for (final event in this) {
      events.add(
        TraceSpanEvent(
          name: event.name,
          timeUnixNano: event.timestamp,
          droppedAttributesCount: event.droppedAttributesCount,
          attributes: event.attributes.toTraceAttributes(),
        ),
      );
    }

    return events;
  }
}

extension SpanLinkListX on List<otel_api.SpanLink> {
  List<TraceSpanLink> toTraceSpanLinksList() {
    final links = <TraceSpanLink>[];
    for (final link in this) {
      links.add(TraceSpanLink(
        traceId: link.context.traceId.toString(),
        spanId: link.context.spanId.toString(),
        traceState: link.context.traceState.toString(),
        attributes: link.attributes.toTraceAttributes(),
      ));
    }
    return links;
  }
}
