import 'package:opentelemetry/api.dart' as otel_api;

abstract class Span {
  String get traceId;
  String get spanId;
  bool get wasEnded;

  void setStatus(SpanStatusCode statusCode, {String? message});
  void addEvent(String message, {Map<String, String> attributes});
  void setAttributes(Map<String, String> attributes);
  void end();
}

class InternalSpan implements Span {
  InternalSpan._({required otel_api.Span otelSpan}) : _otelSpan = otelSpan;

  final otel_api.Span _otelSpan;

  otel_api.Span get otelSpan => _otelSpan;

  @override
  String get traceId => _otelSpan.spanContext.traceId.toString();

  @override
  String get spanId => _otelSpan.spanContext.spanId.toString();

  bool _wasEnded = false;

  @override
  bool get wasEnded => _wasEnded;

  @override
  void setStatus(SpanStatusCode statusCode, {String? message}) {
    if (message != null) {
      _otelSpan.setStatus(statusCode.toOtelStatusCode(), message);
    } else {
      _otelSpan.setStatus(statusCode.toOtelStatusCode());
    }
  }

  @override
  void addEvent(String message, {Map<String, String> attributes = const {}}) {
    final listAttributes = attributes.entries.map((entry) {
      return otel_api.Attribute.fromString(entry.key, entry.value);
    }).toList();
    _otelSpan.addEvent(message, attributes: listAttributes);
  }

  @override
  void setAttributes(Map<String, String> attributes) {
    final listAttributes = attributes.entries.map((entry) {
      return otel_api.Attribute.fromString(entry.key, entry.value);
    }).toList();
    _otelSpan.setAttributes(listAttributes);
  }

  @override
  void end() {
    _wasEnded = true;
    _otelSpan.end();
  }

  String toHttpTraceparent() {
    // W3CTraceContextPropagator stuff.
    // Copied from the OtelSift implementation
    // https://github.com/open-telemetry/opentelemetry-swift/blob/7bad8ae7f230e7a1b9ec697f36dcae91a8debff9/Sources/OpenTelemetryApi/Trace/Propagation/W3CTraceContextPropagator.swift
    const version = '00';
    const delimiter = '-';
    const endString = '01';
    final traceparent =
        '$version$delimiter$traceId$delimiter$spanId$delimiter$endString';
    return traceparent;
  }
}

class SpanProvider {
  Span getSpan(otel_api.Span otelSpan) {
    return InternalSpan._(otelSpan: otelSpan);
  }
}

enum SpanStatusCode {
  /// The default status.
  unset,

  /// The operation contains an error.
  error,

  /// The operation has been validated by an Application developers or
  /// Operator to have completed successfully.
  ok,
}

extension StatusCodeX on SpanStatusCode {
  otel_api.StatusCode toOtelStatusCode() {
    switch (this) {
      case SpanStatusCode.unset:
        return otel_api.StatusCode.unset;
      case SpanStatusCode.error:
        return otel_api.StatusCode.error;
      case SpanStatusCode.ok:
        return otel_api.StatusCode.ok;
    }
  }
}
