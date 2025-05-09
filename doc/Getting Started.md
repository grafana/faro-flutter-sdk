# Faro Flutter SDK

## Getting Started

- Installation
- Initialize Faro

### Onboarding

### Installation

Add the following dependencies to your `pubspec.yaml`

```yml
faro:
  git:
    url: <git_url>
    path: packages/faro
    ref: main
```

### Setup Grafana Alloy

- Set up a [Grafana Alloy](https://grafana.com/docs/alloy/latest/configure/) instance.
- Configure your instance with [app-agent-receiver](https://grafana.com/docs/alloy/latest/reference/components/faro/faro.receiver/#server-block) integration. The integration exposes an http collection endpoint.

### Initialize Faro

Add the following snippet to initialize Faro Monitoring with the default configurations
use the faro.receiver endpoint as collectorUrl in FaroConfig

```dart

  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current); // enable http tracking

  Faro().runApp(
    optionsConfiguration: FaroConfig(
        appName: "<App_Name>",
        appVersion: "1.0.0",
        appEnv: "Test",
        apiKey: "<API_KEY>",
        collectorUrl: "faro receiver endpoint"
    ),
    appRunner: () => runApp(
     FaroUserInteractionWidget(child: MyApp())
    ),
  );

```

See all [configuration](./Configurations.md) options for Faro Flutter
