import 'package:faro/faro.dart';
import 'package:faro/src/util/constants.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

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
          FaroConstants.sdkName,
        ),
        otel_api.Attribute.fromString(
          'telemetry.sdk.language',
          'dart',
        ),
        otel_api.Attribute.fromString(
          'telemetry.sdk.version',
          FaroConstants.sdkVersion,
        ),
        otel_api.Attribute.fromString(
          'telemetry.sdk.platform',
          'flutter',
        ),

        // Session attributes
        ..._buildSessionAttributes(faro.meta.session?.attributes),
      ],
    );
  }

  List<otel_api.Attribute> _buildSessionAttributes(
      Map<String, dynamic>? sessionAttributes) {
    if (sessionAttributes == null) return [];

    return sessionAttributes.entries
        .map((entry) => otel_api.Attribute.fromString(
            entry.key, entry.value?.toString() ?? ''))
        .toList();
  }
}
