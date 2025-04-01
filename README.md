# Grafana Faro Flutter SDK

<img src="./docs/assets/faro_logo.png" alt="Grafana Faro logo" width="500" />

The Grafana Faro Flutter SDK enables real user monitoring (RUM) for mobile applications by instrumenting Flutter apps to collect telemetry.

The collected data can be visualized in **Grafana Mobile Observability** (currently in private beta), which will provide immediate, clear, actionable insights into the end user experience of your Flutter applications. Similar to [Grafana Frontend Observability](https://grafana.com/products/cloud/frontend-observability-for-real-user-monitoring/), but with a focus on mobile-specific vitals and telemetry, this will allow you to monitor real-time mobile app health, track errors, and resolve issues with end-to-end visibility across your stack.

Importantly, you don't need to rely on Grafana Mobile Observability in Grafana Cloud to benefit from this SDK. The telemetry data can be forwarded to [Grafana Alloy](https://grafana.com/docs/alloy/latest/) (with faro receiver integration enabled) and then made accessible in a observability vendor of your choice and integrate Faro's powerful mobile instrumentation into your existing observability workflow.

## Features

The Faro Flutter SDK provides real user monitoring capabilities including:

- **Device Information**: OS, version, Flutter version
- **Application Information**: App name, version, environment
- **Session Information**: Session tracking and events
- **Performance Monitoring**:
  - CPU and memory usage
  - Cold/warm start metrics
  - ANR (Application Not Responding) detection
- **Error Tracking**: Automatic capture of Flutter errors and exceptions
- **User Interaction**: Track user events, interactions, navigation patterns, and complete user flows through your application
- **HTTP Network Monitoring**: Request/response details and timing
- **Asset Loading**: Track asset loading performance
- **Offline Support**: Caching of events when offline

See [Features Documentation](./docs/Features.md) for a complete list.

## Getting Started

### Installation

> **Note:** The Faro Flutter SDK is not yet published on pub.dev. You need to reference the git repository directly for now. The package will be published to pub.dev very soonish, which will simplify the installation process.

Add the following dependencies to your `pubspec.yaml`:

```yaml
faro:
  git:
    url: https://github.com/grafana/faro-flutter-sdk.git
    ref: <version number>
```

### Initialize Faro

Add the following snippet to initialize Faro Monitoring with the default configurations:

```dart
HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current); // enable HTTP tracking

Faro().runApp(
  optionsConfiguration: FaroConfig(
      appName: "<App_Name>",
      appVersion: "1.0.0",
      appEnv: "Production",
      apiKey: "<API_KEY>",
      collectorUrl: "faro receiver endpoint"
  ),
  appRunner: () => runApp(
   FaroUserInteractionWidget(child: MyApp())
  ),
);
```

## Documentation

- [Getting Started Guide](./docs/Getting%20Started.md)
- [Configuration Options](./docs/Configurations.md)
- [Feature Documentation](./docs/Features.md)

## Releases

Faro releases follow the [Semantic Versioning](https://semver.org/) naming scheme: `MAJOR.MINOR.PATCH`.

- `MAJOR`: Major releases include large new features which will significantly change how Faro operates and possible backwards-compatibility breaking changes.
- `MINOR`: These releases include new features which generally do not break backwards-compatibility.
- `PATCH`: Patch releases include bug and security fixes which do not break backwards-compatibility.

## Contributing

Contributions to the Faro Flutter SDK are welcome! Please see our contributing guidelines for more information.

## License

Grafana Faro Flutter SDK is distributed under the terms of the [Apache License 2.0](LICENSE).
