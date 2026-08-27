import 'package:equatable/equatable.dart';
import 'package:faro/src/tracing/span.dart';

/// Identifies the span that a signal (log, event, exception, or measurement)
/// belongs to within a distributed trace.
///
/// This is the Faro equivalent of an OpenTelemetry `SpanContext`: the
/// `trace_id`/`span_id` pair used to correlate a signal with a span. Pass it to
/// `pushLog`, `pushEvent`, `pushError`, or `pushMeasurement`. When a span is
/// active, the SDK attaches the active span's context automatically, so a
/// manual [FaroSpanContext] is only needed to override that or to correlate
/// with a span you obtained elsewhere (for example, ids received from a backend
/// or a WebView handoff).
///
/// The [traceId] and [spanId] must be lowercase-hex strings in
/// [W3C Trace Context](https://www.w3.org/TR/trace-context/) format, which
/// OpenTelemetry also conforms to: a 32-character `traceId` (16 bytes) and a
/// 16-character `spanId` (8 bytes), neither all-zeroes. Ids that don't match
/// won't correlate in Grafana/Tempo. Note: the SDK does not validate this.
///
/// If you already hold a [Span], use its `spanContext` getter instead of
/// constructing this manually.
class FaroSpanContext extends Equatable {
  /// Creates a span context from a [traceId] and [spanId].
  const FaroSpanContext({required this.traceId, required this.spanId});

  /// The id of the trace this signal belongs to.
  final String traceId;

  /// The id of the span this signal belongs to.
  final String spanId;

  /// Serializes to the Faro payload shape with snake_case keys.
  Map<String, String> toJson() {
    return {'trace_id': traceId, 'span_id': spanId};
  }

  @override
  List<Object?> get props => [traceId, spanId];

  @override
  String toString() {
    return 'FaroSpanContext(traceId: $traceId, spanId: $spanId)';
  }
}

/// Convenience access to a span's [FaroSpanContext].
extension SpanContextX on Span {
  /// The [FaroSpanContext] describing this span's trace and span ids.
  FaroSpanContext get spanContext {
    return FaroSpanContext(traceId: traceId, spanId: spanId);
  }
}
