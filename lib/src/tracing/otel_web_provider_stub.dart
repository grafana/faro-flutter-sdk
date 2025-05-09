import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

class WebTracerProvider implements otel_api.TracerProvider {
  WebTracerProvider({
    required otel_sdk.Resource resource,
    required List<otel_sdk.SpanProcessor> processors,
  }) {
    throw UnsupportedError(
        'WebTracerProvider stub should not be used on this platform.');
  }

  @override
  otel_api.Tracer getTracer(String name,
      {String? version,
      String? schemaUrl,
      List<otel_api.Attribute>? attributes}) {
    throw UnimplementedError();
  }

  @override
  void forceFlush() => throw UnimplementedError();

  @override
  void shutdown() => throw UnimplementedError();
}
