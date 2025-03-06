# Faro Flutter SDK

Grafana Faro SDK for Flutter applications - Monitor your Flutter app with ease.

## Getting Started

This project is a Flutter implementation of the Grafana Faro protocol for mobile observability. It allows Flutter applications to send monitoring data to Grafana Cloud, providing comprehensive insights into app performance, user interactions, errors, and more.

## Features

- Performance monitoring (CPU, memory, app startup time)
- Exception and error tracking
- User interaction tracking
- Network request monitoring
- Session tracking
- Custom events and measurements

## Usage

```dart
import 'package:faro/faro_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Faro().runApp(
    optionsConfiguration: FaroConfig(
      appName: "my_app",
      appVersion: "1.0.0",
      appEnv: "production",
      apiKey: "your-api-key",
      collectorUrl: "your-collector-url",
      enableCrashReporting: true,
    ),
    appRunner: () async {
      runApp(MyApp());
    }
  );
}
```

For more information, see the [online documentation](https://flutter.dev/docs).
