import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/util/constants.dart';

class DartOtelTracerResourcesFactory {
  Map<String, Object> getTracerResourceAttributes() {
    final faro = Faro();
    const unknownString = 'unknown';

    final attributes = <String, Object>{
      // App info
      'service.name': faro.meta.app?.name ?? unknownString,
      'deployment.environment': faro.meta.app?.environment ?? unknownString,
      'service.version': faro.meta.app?.version ?? unknownString,
      'service.namespace': faro.meta.app?.namespace ?? 'flutter_app',

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
