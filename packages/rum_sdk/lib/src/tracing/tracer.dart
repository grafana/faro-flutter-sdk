import 'package:opentelemetry/api.dart' as otel_api;
import 'package:rum_sdk/rum_flutter.dart';
import 'package:rum_sdk/src/tracing/span.dart';

class Tracer {
  Tracer._({required otel_api.Tracer otelTracer}) : _otelTracer = otelTracer;

  final otel_api.Tracer _otelTracer;
  Span? _activeSpan;

  /// Creates a new span with the given name and returns it.
  ///
  /// If [isActive] is true, the span will be set as the active span, and any
  /// spans created after this one (where [parentSpan] is not provided) will be
  /// children of this active span (Until this active span is ended).
  /// Any previously defined active span will be replaced by this new span.
  ///
  /// If [parentSpan] is provided, the new span
  /// will be a child of the provided parentSpan.
  Span startSpan(
    String name, {
    bool isActive = false,
    Span? parentSpan,
    Map<String, dynamic> attributes = const {},
  }) {
    final activeSpan = _validateAndGetActiveSpan(isCurrentSpanActive: isActive);

    otel_api.Context? context;
    if (parentSpan != null && parentSpan is InternalSpan) {
      context = otel_api.contextWithSpan(
        otel_api.globalContextManager.active,
        parentSpan.otelSpan,
      );
    } else if (activeSpan != null) {
      context = otel_api.contextWithSpan(
        otel_api.globalContextManager.active,
        activeSpan.otelSpan,
      );
    }

    final otel_api.Span otelSpan;
    if (context == null) {
      otelSpan = _otelTracer.startSpan(
        name,
        kind: otel_api.SpanKind.client,
      );
    } else {
      otelSpan = _otelTracer.startSpan(
        name,
        context: context,
        kind: otel_api.SpanKind.client,
      );
    }

    otelSpan.setAttributes(
      attributes.entries.map((entry) {
        return otel_api.Attribute.fromString(entry.key, entry.value.toString());
      }).toList(),
    );

    final rumFlutter = RumFlutter();

    final sessionId = rumFlutter.meta.session?.id ?? '';
    otelSpan.setAttributes([
      otel_api.Attribute.fromString('session_id', sessionId),
      otel_api.Attribute.fromString('session.id', sessionId),
    ]);

    final span = SpanProvider().getSpan(otelSpan);
    if (isActive) {
      _activeSpan = span;
    }

    return span;
  }

  InternalSpan? _validateAndGetActiveSpan({required bool isCurrentSpanActive}) {
    final activeSpan = _activeSpan;
    if (isCurrentSpanActive ||
        activeSpan == null ||
        activeSpan.wasEnded ||
        activeSpan is! InternalSpan) {
      _activeSpan = null;
      return null;
    }
    return activeSpan;
  }
}

class TracerBuilder {
  Tracer buildTracer({required otel_api.Tracer otelTracer}) {
    return Tracer._(otelTracer: otelTracer);
  }
}
