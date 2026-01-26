import 'package:faro/src/tracing/extensions.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

/// Represents a span in a distributed trace.
///
/// Spans are used to track operations and can contain attributes, events,
/// and status information.
abstract class Span {
  String get traceId;
  String get spanId;
  bool get wasEnded;
  SpanStatusCode get status;
  bool get statusHasBeenSet;

  void setStatus(SpanStatusCode statusCode, {String? message});

  /// Adds an event to the span with optional typed attributes.
  ///
  /// Attributes can be of type String, int, double, or bool.
  /// Other types will be converted to strings.
  void addEvent(String message, {Map<String, Object> attributes});

  /// Sets multiple attributes on the span with typed values.
  ///
  /// Attributes can be of type String, int, double, or bool.
  /// Other types will be converted to strings.
  void setAttributes(Map<String, Object> attributes);

  /// Sets a single attribute on the span with a typed value.
  ///
  /// Supported types: String, int, double, bool.
  /// Other types will be converted to strings.
  void setAttribute(String key, Object value);

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

  bool _statusHasBeenSet = false;

  @override
  bool get statusHasBeenSet => _statusHasBeenSet;

  @override
  void setStatus(SpanStatusCode statusCode, {String? message}) {
    if (message != null) {
      _otelSpan.setStatus(statusCode.toOtelStatusCode(), message);
    } else {
      _otelSpan.setStatus(statusCode.toOtelStatusCode());
    }
    _statusCode = statusCode;
    _statusHasBeenSet = true;
  }

  @override
  void addEvent(String message, {Map<String, Object> attributes = const {}}) {
    final listAttributes = _convertToOtelAttributes(attributes);
    _otelSpan.addEvent(message, attributes: listAttributes);
  }

  @override
  void setAttributes(Map<String, Object> attributes) {
    final listAttributes = _convertToOtelAttributes(attributes);
    _otelSpan.setAttributes(listAttributes);
  }

  @override
  void setAttribute(String key, Object value) {
    _otelSpan.setAttribute(_createOtelAttribute(key, value));
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

  /// Converts a map of typed attributes to OpenTelemetry Attributes.
  List<otel_api.Attribute> _convertToOtelAttributes(
      Map<String, Object> attributes) {
    return attributes.entries.map((entry) {
      return _createOtelAttribute(entry.key, entry.value);
    }).toList();
  }

  /// Creates an OpenTelemetry Attribute from a typed value.
  otel_api.Attribute _createOtelAttribute(String key, Object value) {
    if (value is String) {
      return otel_api.Attribute.fromString(key, value);
    } else if (value is int) {
      return otel_api.Attribute.fromInt(key, value);
    } else if (value is double) {
      return otel_api.Attribute.fromDouble(key, value);
    } else if (value is bool) {
      return otel_api.Attribute.fromBoolean(key, value);
    } else {
      // Fallback: convert to string for unsupported types
      return otel_api.Attribute.fromString(key, value.toString());
    }
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
