import 'dart:async';

import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/dart_otel_tracer_resources_factory.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/tracing/faro_zone_span_manager.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class FaroTracer {
  FaroTracer({
    required otel_api.Tracer otelTracer,
    required FaroZoneSpanManager faroZoneSpanManager,
    required SessionIdProvider sessionIdProvider,
  })  : _otelTracer = otelTracer,
        _faroZoneSpanManager = faroZoneSpanManager,
        _sessionIdProvider = sessionIdProvider;

  final otel_api.Tracer _otelTracer;
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

    var context = otel_api.Context.current;
    if (resolvedParentSpan != null && resolvedParentSpan is InternalSpan) {
      context = otel_api.contextWithSpan(
        resolvedParentSpan.context,
        resolvedParentSpan.otelSpan,
      );
    }

    final otelSpan = _otelTracer.startSpan(
      name,
      context: context,
      kind: otel_api.SpanKind.client,
    );

    final sessionId = _sessionIdProvider.sessionId;
    final allAttributes = <String, Object>{
      ...attributes,
      'session_id': sessionId,
      'session.id': sessionId,
    };

    otelSpan.setAttributes(
      allAttributes.entries.map((entry) {
        return _createOtelAttribute(entry.key, entry.value);
      }).toList(),
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

class FaroTracerFactory {
  static FaroTracer? _faroTracer;

  FaroTracer create() {
    if (_faroTracer != null) {
      return _faroTracer!;
    }

    final exporter = FaroExporterFactory().create();
    final resource = DartOtelTracerResourcesFactory().getTracerResource();
    final provider = otel_sdk.TracerProviderBase(
      resource: resource,
      processors: [otel_sdk.SimpleSpanProcessor(exporter)],
    );
    otel_api.registerGlobalTracerProvider(provider);
    final otelTracer = provider.getTracer(
      'flutter-faro-instrumentation',
    );

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
