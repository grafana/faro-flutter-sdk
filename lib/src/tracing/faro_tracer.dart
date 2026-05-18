import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/faro_zone_span_manager.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/tracing/span_exception_options.dart';

class FaroTracer {
  FaroTracer({
    required otel.APITracer otelTracer,
    required FaroZoneSpanManager faroZoneSpanManager,
    required SessionIdProvider sessionIdProvider,
  }) : _otelTracer = otelTracer,
       _faroZoneSpanManager = faroZoneSpanManager,
       _sessionIdProvider = sessionIdProvider;

  final otel.APITracer _otelTracer;
  final FaroZoneSpanManager _faroZoneSpanManager;
  final SessionIdProvider _sessionIdProvider;

  /// Starts an active span and executes the provided callback within its
  /// context.
  ///
  /// [attributes] can contain typed values (String, int, double, bool).
  /// Other types will be converted to strings.
  ///
  /// [contextScope] controls how long the span remains active in context:
  /// - [ContextScope.callback] (default): Span is deactivated when callback
  ///   completes. Async operations scheduled within the callback (like timers)
  ///   won't see this span as parent after the callback ends.
  /// - [ContextScope.zone]: Span remains active for all async operations in
  ///   the zone, including timers and streams created within the callback.
  FutureOr<T> startSpan<T>(
    String name,
    FutureOr<T> Function(Span) body, {
    Map<String, Object> attributes = const {},
    Span? parentSpan,
    ContextScope contextScope = ContextScope.callback,
    SpanExceptionOptions? exceptionOptions,
  }) async {
    final span = _createAndStartSpan(
      name: name,
      attributes: attributes,
      parentSpan: parentSpan,
    );
    return _faroZoneSpanManager.executeWithSpan(
      span,
      body,
      contextScope: contextScope,
      exceptionOptions: exceptionOptions,
    );
  }

  /// Starts a span without executing a callback, giving manual control over
  /// when the span ends.
  ///
  /// [attributes] can contain typed values (String, int, double, bool).
  /// Other types will be converted to strings.
  Span startSpanManual(
    String name, {
    Map<String, Object> attributes = const {},
    Span? parentSpan,
  }) {
    return _createAndStartSpan(
      name: name,
      attributes: attributes,
      parentSpan: parentSpan,
    );
  }

  Span? getActiveSpan() {
    return _faroZoneSpanManager.getActiveSpan();
  }

  Span _createAndStartSpan({
    required String name,
    required Map<String, Object> attributes,
    Span? parentSpan,
  }) {
    final resolvedParentSpan = _resolveParentSpan(parentSpan);

    var context = otel.Context.current;
    if (resolvedParentSpan != null && resolvedParentSpan is InternalSpan) {
      context = resolvedParentSpan.context
          .withSpan(resolvedParentSpan.otelSpan);
    }

    final sessionId = _sessionIdProvider.sessionId;
    final allAttributes = <String, Object>{
      ...attributes,
      'session_id': sessionId,
      'session.id': sessionId,
    };

    final otelSpan = _otelTracer.startSpan(
      name,
      context: context,
      kind: otel.SpanKind.client,
      attributes: otel.OTel.attributesFromMap(allAttributes),
    );

    return SpanProvider().getSpan(otelSpan, context);
  }

  /// Resolves the effective parent span based on three-state logic:
  /// - [Span.noParent]: explicitly no parent (starts a new root trace)
  /// - `null`: use active span from zone context (default behavior)
  /// - Specific [Span]: use that span as the parent
  Span? _resolveParentSpan(Span? parentSpan) {
    if (parentSpan == Span.noParent) {
      return null;
    }
    return parentSpan ?? getActiveSpan();
  }
}

class FaroTracerFactory {
  static FaroTracer? _faroTracer;

  /// Resets the cached tracer. Visible for testing.
  static void reset() {
    _faroTracer = null;
  }

  FaroTracer create() {
    final cached = _faroTracer;
    if (cached != null) {
      return cached;
    }

    // Use OTelAPI directly so we degrade to a no-op tracer if the Faro
    // bootstrap (which calls OTel.initialize) hasn't run yet — e.g. when
    // FaroHttpTrackingClient is used in unit tests that never call Faro.init.
    final otelTracer = otel.OTelAPI.tracerProvider()
        .getTracer('flutter-faro-instrumentation');
    final faroZoneSpanManager = FaroZoneSpanManagerFactory().create();
    final sessionIdProvider = SessionIdProviderFactory().create();

    final faroTracer = FaroTracer(
      otelTracer: otelTracer,
      faroZoneSpanManager: faroZoneSpanManager,
      sessionIdProvider: sessionIdProvider,
    );
    _faroTracer = faroTracer;

    return faroTracer;
  }
}
