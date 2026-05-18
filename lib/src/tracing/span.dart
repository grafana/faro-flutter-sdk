import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/tracing/extensions.dart';

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

  /// The W3C Trace Context `traceparent` header value for this span.
  ///
  /// Format: `00-{traceId}-{spanId}-{traceFlags}`
  String get traceparent;

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
    required otel.APISpan otelSpan,
    required otel.Context context,
  }) : _otelSpan = otelSpan,
       _context = context;

  final otel.APISpan _otelSpan;
  final otel.Context _context;

  otel.APISpan get otelSpan => _otelSpan;
  otel.Context get context => _context;

  @override
  String get traceId => _otelSpan.spanContext.traceId.toString();

  @override
  String get spanId => _otelSpan.spanContext.spanId.toString();

  @override
  String get traceparent {
    final traceFlags = _otelSpan.spanContext.traceFlags.asByte
        .toRadixString(16)
        .padLeft(2, '0');
    return '00-$traceId-$spanId-$traceFlags';
  }

  bool _wasEnded = false;

  @override
  bool get wasEnded => _wasEnded || _otelSpan.isEnded;

  SpanStatusCode _statusCode = SpanStatusCode.unset;

  @override
  SpanStatusCode get status {
    final otelStatus = _otelSpan.status;
    if (otelStatus != otel.SpanStatusCode.Unset) {
      return otelStatus.toSpanStatusCode();
    }
    return _statusCode;
  }

  bool _statusHasBeenSet = false;

  @override
  bool get statusHasBeenSet => _statusHasBeenSet;

  @override
  void setStatus(SpanStatusCode statusCode, {String? message}) {
    _otelSpan.setStatus(statusCode.toOtelStatusCode(), message);
    _statusCode = statusCode;
    _statusHasBeenSet = true;
  }

  @override
  void addEvent(String message, {Map<String, Object> attributes = const {}}) {
    final eventAttributes =
        attributes.isEmpty ? null : otel.OTel.attributesFromMap(attributes);
    _otelSpan.addEventNow(message, eventAttributes);
  }

  @override
  void setAttributes(Map<String, Object> attributes) {
    if (attributes.isEmpty) return;
    _otelSpan.addAttributes(otel.OTel.attributesFromMap(attributes));
  }

  @override
  void setAttribute(String key, Object value) {
    if (value is String) {
      _otelSpan.setStringAttribute<String>(key, value);
    } else if (value is bool) {
      _otelSpan.setBoolAttribute(key, value);
    } else if (value is int) {
      _otelSpan.setIntAttribute(key, value);
    } else if (value is double) {
      _otelSpan.setDoubleAttribute(key, value);
    } else {
      _otelSpan.setStringAttribute<String>(key, value.toString());
    }
  }

  @override
  void recordException(dynamic exception, {StackTrace? stackTrace}) {
    _otelSpan.recordException(
      exception,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  @override
  void end() {
    _wasEnded = true;
    _otelSpan.end();
  }
}

class SpanProvider {
  Span getSpan(otel.APISpan otelSpan, otel.Context context) {
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
  String get traceparent => throw UnsupportedError(_errorMessage);

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

/// Controls how long the span remains active in context for automatic parent
/// assignment.
///
/// When using [FaroTracer.startSpan], this determines whether the span should
/// be deactivated from the zone context when the callback completes.
enum ContextScope {
  /// Span is removed from context when the callback completes.
  ///
  /// Async operations scheduled within the callback (e.g., timers, streams)
  /// that execute after the callback completes will NOT see this span as their
  /// parent. This is the default behavior and is correct for most use cases.
  ///
  /// Example:
  /// ```dart
  /// await Faro().startSpan('parent', (span) async {
  ///   Timer.periodic(Duration(seconds: 1), (timer) {
  ///     // This timer callback runs AFTER the parent callback completes,
  ///     // so spans created here won't have 'parent' as their parent.
  ///     Faro().startSpan('timer-work', (s) async { ... });
  ///   });
  /// });
  /// ```
  callback,

  /// Span remains active in context for all async operations in the zone.
  ///
  /// Use this when you intentionally want async operations scheduled within
  /// the callback (like timers or streams) to inherit this span as their
  /// parent, even after the callback completes.
  ///
  /// Example:
  /// ```dart
  /// await Faro().startSpan('background-monitor',
  ///   contextScope: ContextScope.zone,
  ///   (span) async {
  ///     Timer.periodic(Duration(minutes: 1), (timer) {
  ///       // These timer spans WILL have 'background-monitor' as parent
  ///       Faro().startSpan('health-check', (s) async { ... });
  ///     });
  ///   },
  /// );
  /// ```
  zone,
}
