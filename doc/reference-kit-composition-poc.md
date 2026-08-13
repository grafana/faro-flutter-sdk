# Flutter Reference Kit composition POC

## Goal

Test whether a Grafana Reference Kit can add Grafana behavior while preserving
direct access to the selected telemetry SDK. The POC intentionally avoids a
wrapper that would need to mirror every Faro or OpenTelemetry method.

## Shape

```dart
final otelSdk = FutureOpenTelemetrySdk();
final kit = GrafanaReferenceKit(
  sdk: otelSdk,
  plugins: [GrafanaCloudPlugin()],
);

await kit.start();

// The application still uses the native SDK directly.
kit.sdk.tracerProvider.getTracer('checkout');
```

`GrafanaReferenceKit` owns only plugin lifecycle:

- It preserves the exact SDK object supplied by the application.
- It starts Grafana plugins in registration order.
- It stops them in reverse order.
- It rolls back partially installed plugins when startup fails.
- It does not proxy tracing, logging, metrics, or other native SDK methods.

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

Composition is viable without creating a broad Grafana shim. The remaining
design question is the concrete lifecycle and extension API offered by the
future Flutter OpenTelemetry SDK.
