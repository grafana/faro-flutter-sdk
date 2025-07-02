import 'dart:async';

import 'package:faro/faro_sdk.dart';
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/dart_otel_tracer_resources_factory.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/tracing/faro_zone_span_manager.dart';
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

  FutureOr<T> startSpan<T>(
    String name,
    FutureOr<T> Function(Span) body, {
    Map<String, String> attributes = const {},
    Span? parentSpan,
  }) async {
    final span = _createAndStartSpan(
      name: name,
      attributes: attributes,
      parentSpan: parentSpan,
    );
    return _faroZoneSpanManager.executeWithSpan(span, body);
  }

  Span startSpanManual(
    String name, {
    Map<String, String> attributes = const {},
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
    required Map<String, String> attributes,
    Span? parentSpan,
  }) {
    final theParentSpan = parentSpan ?? getActiveSpan();
    var context = otel_api.Context.current;
    if (theParentSpan != null && theParentSpan is InternalSpan) {
      context = otel_api.contextWithSpan(
        theParentSpan.context,
        theParentSpan.otelSpan,
      );
    }

    final otelSpan = _otelTracer.startSpan(
      name,
      context: context,
      kind: otel_api.SpanKind.client,
    );

    final sessionId = _sessionIdProvider.sessionId;
    final allAttributes = <String, String>{
      ...attributes,
      'session_id': sessionId,
      'session.id': sessionId,
    };

    otelSpan.setAttributes(
      allAttributes.entries.map((entry) {
        return otel_api.Attribute.fromString(entry.key, entry.value);
      }).toList(),
    );

    return SpanProvider().getSpan(otelSpan, context);
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
