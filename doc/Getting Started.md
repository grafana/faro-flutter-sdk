# Getting Started with Faro Flutter SDK

The Faro Flutter SDK enables real-time observability for your Flutter applications by collecting logs, errors, performance metrics, and user interactions. This data is sent to Grafana Cloud or your self-hosted Grafana Alloy instance for monitoring and analysis.

## Installation

Add the following dependency to your `pubspec.yaml`:

```yml
dependencies:
  faro: ^<latest_version>
```

## Choose Your Setup Method

You have two options for collecting Faro telemetry data:

### Option 1: Grafana Cloud Frontend Observability (Recommended)

If you're using Grafana Cloud, this is the easiest setup:

1. Navigate to your **Grafana Cloud instance**
2. Go to **Frontend Observability** in the left sidebar
3. Click **Create New** or select an existing application
4. In the **Add Faro to your application/Web SDK Config** section, you'll find:
   - **Faro Endpoint URL**: This is your `collectorUrl`

> 💡 **Tip**: The API key is also the last segment of your Faro endpoint URL

### Option 2: Self-Hosted with Grafana Alloy

For self-hosted setups:

1. Set up a [Grafana Alloy](https://grafana.com/docs/alloy/latest/configure/) instance
2. Configure the [faro.receiver component](https://grafana.com/docs/alloy/latest/reference/components/faro/faro.receiver/#server-block)
3. Use the receiver's HTTP endpoint as your `collectorUrl`
4. Generate an API key for authentication

## Initialize Faro in Your App

Add this code to your Flutter app's main function:

```dart
import 'dart:io';
import 'package:faro/faro_sdk.dart';

void main() {
  // Enable HTTP request tracking
  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);

  Faro().runApp(
    optionsConfiguration: FaroConfig(
      appName: "my-flutter-app",           // Your app's name
      appVersion: "1.0.0",                // Current app version
      appEnv: "production",               // Environment (development/staging/production)
      apiKey: "your-api-key-here",        // From Grafana Cloud or your setup
      collectorUrl: "https://faro-collector-url-here/collect/12345", // Faro endpoint
      collectorHeaders: {
        // Optional: Additional headers for the collector.
        // Not needed for Grafana Cloud.
        "Custom-Header": "value"
      }
    ),
    appRunner: () => runApp(
      DefaultAssetBundle(
        bundle: FaroAssetBundle(),        // Track asset loading
        child: FaroUserInteractionWidget( // Track user interactions
          child: MyApp()                  // Your app's root widget
        )
      )
    ),
  );
}
```

## Next Steps

- **Configure monitoring features**: See [Configuration Options](./Configurations.md) to enable crash reporting, mobile vitals, and custom tracking
- **Add navigation tracking**: Include `FaroNavigationObserver()` in your app's navigator observers
- **Send custom telemetry**: Use `Faro().pushEvent()`, `Faro().pushLog()`, and other methods to track custom data
- **Explore the telemetry data**: Go to your Grafana Cloud instance and navigate to **Frontend Observability**. Or just start exploring the data in any Grafana dashboard using **Tempo** for the traces and **Loki** for everything else.

## Need Help?

- Check the [Configuration Documentation](./Configurations.md) for advanced setup options
- Review how the example app is using Faro in the `/example` directory
- Visit [Grafana's Frontend Observability docs](https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/) for more information
