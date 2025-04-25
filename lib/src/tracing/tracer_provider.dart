import 'package:faro/faro.dart';
import 'package:faro/src/tracing/dart_otel_tracer_resources_factory.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/tracing/tracer.dart';
import 'package:flutter/foundation.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:opentelemetry/web_sdk.dart' as otel_web_sdk;

abstract class TracerProvider {
  Tracer getTracer();
}

class DartOtelTracerProvider implements TracerProvider {
  static Tracer? _tracer;
  static late otel_api.TracerProvider _otelProvider;

  @override
  Tracer getTracer() {
    if (_tracer != null) {
      return _tracer!;
    }

    final exporter = FaroExporter();
    final resource = DartOtelTracerResourcesFactory().getTracerResource();
    final spanProcessor = otel_sdk.SimpleSpanProcessor(exporter);

    if (kIsWeb) {
      _otelProvider = otel_web_sdk.WebTracerProvider(
        resource: resource,
        processors: [spanProcessor],
      );
    } else {
      _otelProvider = otel_sdk.TracerProviderBase(
        resource: resource,
        processors: [spanProcessor],
      );
    }
    otel_api.registerGlobalTracerProvider(_otelProvider);

    final faro = Faro();
    final otelTracer = _otelProvider.getTracer(
      'main-instrumentation',
      version: faro.meta.app?.version ?? 'unknown',
    );

    final tracer = TracerBuilder().buildTracer(otelTracer: otelTracer);
    _tracer = tracer;
    return tracer;
  }
}
