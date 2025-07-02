import 'package:faro/src/tracing/extensions.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

abstract class Span {
  String get traceId;
  String get spanId;
  bool get wasEnded;
  SpanStatusCode get status;

  void setStatus(SpanStatusCode statusCode, {String? message});
  void addEvent(String message, {Map<String, String> attributes});
  void setAttributes(Map<String, String> attributes);
  void setAttribute(String key, String value);
  void recordException(dynamic exception, {StackTrace? stackTrace});
  void end();
}

class InternalSpan implements Span {
  InternalSpan._({
    required otel_api.Span otelSpan,
    required otel_api.Context context,
  })  : _otelSpan = otelSpan,
        _context = context;

  final otel_api.Span _otelSpan;
  final otel_api.Context _context;

  otel_api.Span get otelSpan => _otelSpan;
  otel_api.Context get context => _context;

  @override
  String get traceId => _otelSpan.spanContext.traceId.toString();

  @override
  String get spanId => _otelSpan.spanContext.spanId.toString();

  bool _wasEnded = false;

  @override
  bool get wasEnded => _wasEnded;

  SpanStatusCode _statusCode = SpanStatusCode.unset;

  @override
  SpanStatusCode get status {
    if (otelSpan is otel_sdk.ReadWriteSpan) {
      final otelSdkSpan = otelSpan as otel_sdk.ReadWriteSpan;
      return otelSdkSpan.status.toSpanStatusCode();
    }
    return _statusCode;
  }

  @override
  void setStatus(SpanStatusCode statusCode, {String? message}) {
    if (message != null) {
      _otelSpan.setStatus(statusCode.toOtelStatusCode(), message);
    } else {
      _otelSpan.setStatus(statusCode.toOtelStatusCode());
    }
    _statusCode = statusCode;
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
  void setAttribute(String key, String value) {
    _otelSpan.setAttribute(otel_api.Attribute.fromString(key, value));
  }

  @override
  void recordException(dynamic exception, {StackTrace? stackTrace}) {
    _otelSpan.recordException(exception,
        stackTrace: stackTrace ?? StackTrace.current);
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
  Span getSpan(otel_api.Span otelSpan, otel_api.Context context) {
    return InternalSpan._(otelSpan: otelSpan, context: context);
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
