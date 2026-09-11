import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/tracing/dartastic_span_access.dart';
import 'package:faro/src/tracing/span.dart';

// Event-only metadata follows the SDK span through batched export without
// becoming OTel attributes. Weak keys also release unsampled/dropped spans.
final _httpEventAttributes = Expando<Map<String, String>>();
final _errorTypeCaptured = Expando<bool>();

/// Captures the existing Faro HTTP event contract separately from OTel.
void initializeHttpEventAttributes(Span span, Map<String, String> attributes) {
  if (span is InternalSpan) {
    _httpEventAttributes[span.otelSpan] = Map.of(attributes);
    _errorTypeCaptured[span.otelSpan] = false;
  }
}

/// Adds event-only HTTP metadata when a response or failure is observed.
void updateHttpEventAttributes(Span span, Map<String, String> attributes) {
  if (span is InternalSpan) {
    _httpEventAttributes[span.otelSpan]?.addAll(attributes);
  }
}

/// Retains the error type that existed before transport error handling.
void preserveHttpEventErrorType(Span span) {
  if (span is InternalSpan && span.otelSpan is otel.Span) {
    if (_errorTypeCaptured[span.otelSpan] == true) return;
    _errorTypeCaptured[span.otelSpan] = true;
    final type = dartasticSpanAttributes(
      span.otelSpan as otel.Span,
    ).getString('error.type');
    if (type != null) updateHttpEventAttributes(span, {'error.type': type});
  }
}

/// Returns a copy so serialization cannot mutate request metadata.
Map<String, String>? httpEventAttributes(Object span) {
  final attributes = _httpEventAttributes[span];
  return attributes == null ? null : Map.of(attributes);
}
