import 'package:faro/faro.dart';
import 'package:faro/src/tracing/dart_otel_tracer_resources_factory.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/tracing/tracer.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

abstract class TracerProvider {
  Tracer getTracer();
}

class DartOtelTracerProvider implements TracerProvider {
  static Tracer? _tracer;

  @override
  Tracer getTracer() {
    if (_tracer != null) {
      return _tracer!;
    }

    final exporter = FaroExporter();
    final resource = DartOtelTracerResourcesFactory().getTracerResource();

    final provider = otel_sdk.TracerProviderBase(
      resource: resource,
      processors: [otel_sdk.SimpleSpanProcessor(exporter)],
    );

    otel_api.registerGlobalTracerProvider(provider);

    final faro = Faro();
    final otelTracer = provider.getTracer(
      'main-instrumentation',
      version: faro.meta.app?.version ?? 'unknown',
    );

    final tracer = TracerBuilder().buildTracer(otelTracer: otelTracer);
    _tracer = tracer;
    return tracer;
  }
}