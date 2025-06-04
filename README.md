# Grafana Faro Flutter SDK

<img src="./doc/assets/faro_logo.png" alt="Grafana Faro logo" width="500" />

[![Flutter checks](https://github.com/grafana/faro-flutter-sdk/actions/workflows/flutter_checks.yml/badge.svg)](https://github.com/grafana/faro-flutter-sdk/actions/workflows/flutter_checks.yml)
![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)
[![pub package](https://img.shields.io/pub/v/faro.svg)](https://pub.dev/packages/faro)
![iOS](https://img.shields.io/badge/iOS-supported-brightgreen?logo=apple&logoColor=white)
![Android](https://img.shields.io/badge/Android-supported-brightgreen?logo=android&logoColor=white)

The Grafana Faro Flutter SDK enables real user monitoring (RUM) for mobile applications by instrumenting Flutter apps to collect telemetry.

The collected data can be visualized in [Grafana Frontend Observability](https://grafana.com/products/cloud/frontend-observability-for-real-user-monitoring/).  
_Please note:_ Grafana Frontend Observability is primarily tailored for web RUM. But the session tracking and error monitoring capabilities work similarly for mobile applications. Additionally, all telemetry data collected by the Faro Flutter SDK is stored in Loki/Tempo, allowing you to create custom dashboards and perform detailed investigations using Loki/Tempo queries within Grafana.

Importantly, you don't need to rely on Grafana Frontend Observability in Grafana Cloud to benefit from this SDK. The telemetry data can be forwarded to [Grafana Alloy](https://grafana.com/docs/alloy/latest/) (with faro receiver integration enabled) and then made accessible in a observability vendor of your choice and integrate Faro's powerful mobile instrumentation into your existing observability workflow.

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

See [Features Documentation](./doc/Features.md) for a complete list.

## Getting Started

### Installation

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  faro: ^<latest_version>
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
      collectorUrl: "faro receiver endpoint",
      collectorHeaders: {
        ... // custom headers to be sent with each request to the collector url
      }
      // ... other configurations
  ),
  appRunner: () => runApp(
    DefaultAssetBundle(
      bundle: FaroAssetBundle(),
      child: FaroUserInteractionWidget(child: MyApp())
    )
  ),
);
```

## Documentation

- [Getting Started Guide](./doc/Getting%20Started.md)
- [Configuration Options](./doc/Configurations.md)
- [Feature Documentation](./doc/Features.md)

## Releases

Faro releases follow the [Semantic Versioning](https://semver.org/) naming scheme: `MAJOR.MINOR.PATCH`.

- `MAJOR`: Major releases include large new features which will significantly change how Faro operates and possible backwards-compatibility breaking changes.
- `MINOR`: These releases include new features which generally do not break backwards-compatibility.
- `PATCH`: Patch releases include bug and security fixes which do not break backwards-compatibility.

## Contributing

Contributions to the Faro Flutter SDK are welcome! Please see our [Contributing Guidelines](CONTRIBUTING.md) for detailed information on how to get started, submit issues, and contribute code.

For questions about the project or need help getting started, feel free to open an issue or reach out to our maintainers.

## License

Grafana Faro Flutter SDK is distributed under the terms of the [Apache License 2.0](LICENSE).
