# Flutter Reference Kit composition POC

## Goal

Test whether a Grafana Reference Kit can compose an OpenTelemetry SDK with
Grafana instrumentation and plugins without creating a second telemetry API.
Applications continue to instrument through the stable OpenTelemetry API. The
underlying SDK remains available only where advanced configuration or extension
points require it.

## Shape

```dart
final otelApi = FutureOpenTelemetryApi();
final otelSdk = FutureOpenTelemetrySdk();
final kit = GrafanaReferenceKit(
  sdk: otelSdk,
  plugins: [GrafanaCloudPlugin()],
);

await kit.start();

// Application instrumentation continues through the stable OTel API.
final tracer = otelApi.getTracer('checkout');

// The SDK remains available for advanced configuration when needed.
kit.sdk.tracerProvider.getTracer('checkout');
```

`GrafanaReferenceKit` owns only plugin lifecycle:

- It does not replace or wrap the OpenTelemetry API used for instrumentation.
- It preserves the exact SDK object for advanced configuration and extensions.
- It starts Grafana plugins in registration order.
- It stops them in reverse order.
- It rolls back partially installed plugins when startup fails.
- It does not define Grafana versions of tracing, logging, or metrics methods.

The POC is generic because the future Flutter OpenTelemetry SDK API is not yet
available. A concrete adapter can be added once that SDK exposes its
initialization and extension points.

## Current Faro constraint

Faro currently initializes `dartastic_opentelemetry` through a process-global
static API. That does not match the proposed `GrafanaReferenceKit(otelSdk)`
constructor because there is no SDK instance to inject. This POC should not be
moved into the public package until we decide whether to:

1. adopt an instance-based Flutter OpenTelemetry SDK,
2. introduce an instance-based boundary around Faro's OTel bootstrap, or
3. keep Faro and OTel initialization as separate concrete plugins.

## Decision this POC supports

Composition is viable without creating a Grafana-specific telemetry API. The
OpenTelemetry API remains the stable customer contract, while the Reference Kit
assembles the SDK with Grafana instrumentation, configuration, and plugins. The
remaining design question is the concrete lifecycle and extension API offered
by the future Flutter OpenTelemetry SDK.
