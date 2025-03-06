import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:faro/faro.dart';

class DartOtelTracerResourcesFactory {
  otel_sdk.Resource getTracerResource() {
    final faro = Faro();
    const unknownString = 'unknown';

    return otel_sdk.Resource(
      [
        // App info
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.serviceName,
          faro.meta.app?.name ?? unknownString,
        ),
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.deploymentEnvironment,
          faro.meta.app?.environment ?? unknownString,
        ),
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.serviceVersion,
          faro.meta.app?.version ?? unknownString,
        ),
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.serviceNamespace,
          faro.meta.app?.namespace ?? 'flutter_app',
        ),

        // Otel info
        otel_api.Attribute.fromString(
          'telemetry.sdk.name',
          'faro-flutter-sdk',
        ),
        otel_api.Attribute.fromString(
          'telemetry.sdk.language',
          'dart',
        ),
        otel_api.Attribute.fromString(
          'telemetry.sdk.version',
          '1.0.0',
        ),
        otel_api.Attribute.fromString(
          'telemetry.sdk.platform',
          'flutter',
        ),
      ],
    );
  }
}
