import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/util/constants.dart';

class DartOtelTracerResourcesFactory {
  Map<String, Object> getTracerResourceAttributes() {
    final faro = Faro();
    const unknownString = 'unknown';

    String orUnknown(String? value, [String fallback = unknownString]) {
      if (value == null || value.isEmpty) return fallback;
      return value;
    }

    final attributes = <String, Object>{
      // App info — dartastic rejects empty strings for service.name and
      // friends, so treat empty values the same as null.
      'service.name': orUnknown(faro.meta.app?.name),
      'deployment.environment': orUnknown(faro.meta.app?.environment),
      'service.version': orUnknown(faro.meta.app?.version),
      'service.namespace': orUnknown(faro.meta.app?.namespace, 'flutter_app'),

      // Otel info
      'telemetry.sdk.name': FaroConstants.sdkName,
      'telemetry.sdk.language': 'dart',
      'telemetry.sdk.version': FaroConstants.sdkVersion,
      'telemetry.sdk.platform': 'flutter',
    };

    final sessionAttributes = faro.meta.session?.attributes;
    if (sessionAttributes != null) {
      for (final entry in sessionAttributes.entries) {
        final value = entry.value;
        if (value == null) continue;
        if (value is String ||
            value is int ||
            value is double ||
            value is bool) {
          attributes[entry.key] = value as Object;
        } else {
          attributes[entry.key] = value.toString();
        }
      }
    }

    return attributes;
  }

  /// Builds a [Resource] from the Faro meta. Requires [OTel.initialize] to have
  /// been called first.
  Resource getTracerResource() {
    final attrs = OTel.attributesFromMap(getTracerResourceAttributes());
    return OTel.resource(attrs);
  }
}
