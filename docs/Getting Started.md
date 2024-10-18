# RUM Flutter - 0.0.1 Alpha

## Getting Started

- Installation
- Initialise RUM

### Onboarding

### Installation

Add the following dependencies to your `pubspec.yaml`

```yml
rum_sdk:
  git:
    url: <git_url>
    path: packages/rum_sdk
    ref: main
```

### Setup Grafana Alloy

- Set up a [Grafana Alloy](https://grafana.com/docs/alloy/latest/configure/) instance.
- Configure your instance with [app-agent-receiver](https://grafana.com/docs/alloy/latest/reference/components/faro/faro.receiver/#server-block) integration. The integration exposes an http collection endpoint.

### Initialise RUM

Add the following snippet to initialize RUM Monitoring with the default configurations
use the faro.receiver endpoint as collectorUrl in RumConfig

```dart

  HttpOverrides.global = RumHttpOverrides(HttpOverrides.current); // enable http tracking

  RumFlutter().runApp(
    optionsConfiguration: RumConfig(
        appName: "<App_Name>",
        appVersion: "1.0.0",
        appEnv: "Test",
        apiKey: "<API_KEY>",
        collectorUrl: "faro receiver endpoint"
    ),
    appRunner: () => runApp(
     RumUserInteractionWidget(child: MyApp())
    ),
  );



```

See all [configuration](./Configurations.md) options for RUM Flutter
