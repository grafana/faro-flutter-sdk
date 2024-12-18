import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:rum_sdk/rum_flutter.dart';

class DartOtelTracerResourcesFactory {
  otel_sdk.Resource getTracerResource() {
    final rumFlutter = RumFlutter();
    const unknownString = 'unknown';

    return otel_sdk.Resource(
      [
        // App info
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.serviceName,
          rumFlutter.meta.app?.name ?? unknownString,
        ),
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.deploymentEnvironment,
          rumFlutter.meta.app?.environment ?? unknownString,
        ),
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.serviceVersion,
          rumFlutter.meta.app?.version ?? unknownString,
        ),
        otel_api.Attribute.fromString(
          otel_api.ResourceAttributes.serviceNamespace,
          rumFlutter.meta.app?.namespace ?? 'flutter_app',
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
