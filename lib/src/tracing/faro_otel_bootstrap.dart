import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/tracing/dart_otel_tracer_resources_factory.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/faro_user_action_span_processor.dart';

/// Initializes the underlying OpenTelemetry SDK for Faro.
///
/// The OpenTelemetry SDK is process-global; we only call [otel.OTel.initialize]
/// once per process. On subsequent [initialize] calls (e.g. after
/// [Faro.resetForTesting] in tests) we keep the existing OTel singleton and
/// only rebuild the [FaroTracer] wrapper, which picks up updated session/app
/// metadata at span-creation time via Faro's session-id provider.
///
/// Resource attributes (service.name, etc.) are captured at the first
/// initialize call. Tests that need to assert against changed resource
/// attributes can await [resetForTesting] before re-initializing.
class FaroOtelBootstrap {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      // OTel is process-global and re-initializing it requires resetting,
      // which involves async shutdown work that can hang under Flutter's
      // fake-async test environment. Once initialized, just refresh the
      // Faro tracer wrapper so it observes the latest pod state.
      FaroTracerFactory.reset();
      return;
    }

    final resourceAttrs = DartOtelTracerResourcesFactory()
        .getTracerResourceAttributes();
    final serviceName =
        resourceAttrs['service.name'] as String? ?? 'unknown';
    final serviceVersion =
        resourceAttrs['service.version'] as String? ?? 'unknown';

    final processor = pod.resolve(faroSpanProcessorProvider);

    await otel.OTel.initialize(
      serviceName: serviceName,
      serviceVersion: serviceVersion,
      tracerName: 'flutter-faro-instrumentation',
      spanProcessor: processor,
      resourceAttributes: otel.OTel.attributesFromMap(resourceAttrs),
      enableMetrics: false,
      enableLogs: false,
      detectPlatformResources: false,
    );

    FaroTracerFactory.reset();
    _initialized = true;
  }

  /// Resets bootstrap state for tests. Awaits a full OTel shutdown.
  static Future<void> resetForTesting() async {
    if (_initialized) {
      // ignore: invalid_use_of_visible_for_testing_member
      await otel.OTel.reset();
    }
    FaroTracerFactory.reset();
    _initialized = false;
  }
}
