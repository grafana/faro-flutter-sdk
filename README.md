# Grafana Faro Flutter SDK

<img src="./doc/assets/faro_logo.png" alt="Grafana Faro logo" width="500" />

[![Flutter checks](https://github.com/grafana/faro-flutter-sdk/actions/workflows/flutter_checks.yml/badge.svg)](https://github.com/grafana/faro-flutter-sdk/actions/workflows/flutter_checks.yml)
![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)
[![pub package](https://img.shields.io/pub/v/faro.svg)](https://pub.dev/packages/faro)
![iOS](https://img.shields.io/badge/iOS-supported-brightgreen?logo=apple&logoColor=white)
![Android](https://img.shields.io/badge/Android-supported-brightgreen?logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web-beta-blue?logo=googlechrome&logoColor=white)

The Grafana Faro Flutter SDK enables real user monitoring (RUM) for Flutter
applications by instrumenting apps to collect telemetry on mobile and, in a
first beta form, on web.

> **Note:** [Grafana Frontend Observability](https://grafana.com/products/cloud/frontend-observability-for-real-user-monitoring/) is built for web applications — there is currently no official mobile observability product from Grafana.
>
> This SDK enables mobile telemetry collection using the Faro protocol. It can work well for many use cases, but please be aware that it is not yet backed by a dedicated mobile product experience in Grafana Cloud.
>
> **What you can expect:**
>
> - Session tracking and error monitoring work similarly to web applications
> - All telemetry data is stored in Loki/Tempo, allowing you to create custom dashboards and run queries in Grafana
> - Data can be forwarded to [Grafana Alloy](https://grafana.com/docs/alloy/latest/) (with faro receiver enabled) and routed to any observability backend of your choice

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
- **User Actions**: Group related telemetry under a single action context to track end-to-end user interactions
- **HTTP Network Monitoring**: Request/response details and timing
- **Asset Loading**: Track asset loading performance
- **Offline Support**: Caching of events when offline

See [SDK Reference](./doc/Reference.md) for complete documentation.

## Getting Started

### Installation

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  faro: ^<latest_version>
```

### Initialize Faro

Add the following snippet to initialize Faro Monitoring with the default
configurations:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);

  await Faro().runApp(
    optionsConfiguration: FaroConfig(
      appName: '<App_Name>',
      appVersion: '1.0.0',
      appEnv: 'Production',
      apiKey: '<API_KEY>',
      collectorUrl: 'faro receiver endpoint',
      collectorHeaders: {
        // custom headers to be sent with each request to the collector url
      },
    ),
    appRunner: () => runApp(
      FaroAssetTracking(
        child: FaroUserInteractionWidget(child: MyApp()),
      ),
    ),
  );
}
```

### Web beta scope

Current web support is intentionally limited to a pragmatic first beta:

- ✅ SDK initialization
- ✅ logs, events, errors, measurements, session tracking, and browser metadata
- ✅ navigation/view metadata
- ✅ asset tracking and user-action infrastructure that already runs in Dart
- ❌ automatic HTTP instrumentation via `FaroHttpOverrides`
- ❌ `OfflineTransport`
- ❌ native mobile vitals (CPU, memory, ANR, refresh rate, app start)

> **Note:** When also targeting web, `FaroHttpOverrides` and `OfflineTransport`
> must be guarded behind platform checks because they rely on `dart:io`. See the
> [SDK Reference](./doc/Reference.md#flutter-web-beta-support) for the full web
> setup.

## Documentation

- [SDK Reference](./doc/Reference.md) — Getting started, features, configuration, and API usage

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
