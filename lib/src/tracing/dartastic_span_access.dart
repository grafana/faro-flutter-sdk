import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;

/// Returns span attributes from Dartastic spans for export/processor code.
///
/// Dartastic currently marks [otel.Span.attributes] as testing-only, but Faro
/// needs read access when serializing ended spans and inspecting Faro span
/// markers in processors. Keep that access isolated here while Dartastic's
/// exporter-readable span API settles.
otel.Attributes dartasticSpanAttributes(otel.Span span) {
  // ignore: invalid_use_of_visible_for_testing_member
  return span.attributes;
}
