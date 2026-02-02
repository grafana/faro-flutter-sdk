import 'package:faro/src/tracing/extensions.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

/// Represents a span in a distributed trace.
///
/// Spans are used to track operations and can contain attributes, events,
/// and status information.
abstract class Span {
  /// Sentinel value to explicitly start a span with no parent.
  ///
  /// Use this when you want to start a new root trace, ignoring any active
  /// span in the current zone context. This is useful in scenarios like:
  /// - Timer callbacks where the original parent span has ended
  /// - Starting independent traces from within an existing span's context
  /// - Event-driven architectures where span context shouldn't propagate
  ///
  /// Example:
  /// ```dart
  /// // Inside a timer callback where parent span may have ended
  /// Timer.periodic(Duration(seconds: 1), (_) {
  ///   Faro().startSpan('timer-operation', parentSpan: Span.noParent, (span) {
  ///     // This span starts a new trace, not inheriting from context
  ///   });
  /// });
  /// ```
  ///
  /// Note: This is a sentinel value only. Do not call any methods on it.
  static const Span noParent = _NoParentSpan();

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

/// Private sentinel class for [Span.noParent].
///
/// This class exists only as a marker/sentinel value. All methods throw
/// [UnsupportedError] because this object should never be used as an actual
/// span - it's only meant to be passed to the `parentSpan` parameter.
class _NoParentSpan implements Span {
  const _NoParentSpan();

  static const _errorMessage =
      'Span.noParent is a sentinel value for the parentSpan parameter only. '
      'It cannot be used as an actual span.';

  @override
  String get traceId => throw UnsupportedError(_errorMessage);

  @override
  String get spanId => throw UnsupportedError(_errorMessage);

  @override
  bool get wasEnded => throw UnsupportedError(_errorMessage);

  @override
  SpanStatusCode get status => throw UnsupportedError(_errorMessage);

  @override
  bool get statusHasBeenSet => throw UnsupportedError(_errorMessage);

  @override
  void setStatus(SpanStatusCode statusCode, {String? message}) =>
      throw UnsupportedError(_errorMessage);

  @override
  void addEvent(String message, {Map<String, Object> attributes = const {}}) =>
      throw UnsupportedError(_errorMessage);

  @override
  void setAttributes(Map<String, Object> attributes) =>
      throw UnsupportedError(_errorMessage);

  @override
  void setAttribute(String key, Object value) =>
      throw UnsupportedError(_errorMessage);

  @override
  void recordException(dynamic exception, {StackTrace? stackTrace}) =>
      throw UnsupportedError(_errorMessage);

  @override
  void end() => throw UnsupportedError(_errorMessage);
}
