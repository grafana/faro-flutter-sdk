# Faro SDK Example

This example demonstrates how to integrate and use the Grafana Faro SDK in a Flutter application.

## Architecture

This example app follows a **feature-based architecture** with clear separation of concerns. When adding new features, follow the patterns established in the `tracing` feature.

### Feature Structure

Each feature should be organized as follows:

```
lib/features/<feature_name>/
├── domain/           # Business logic and services
│   └── <feature>_service.dart
├── models/           # Data models (DTOs, entities)
│   └── <model>.dart
└── presentation/     # UI layer
    ├── <feature>_page.dart
    └── <feature>_page_view_model.dart
```

### State Management (Riverpod)

We use **Riverpod** with a ViewModel pattern that separates UI state from actions:

- **UiState class**: Immutable data class (with Equatable) containing all UI state
- **Actions interface**: Defines all user actions the page can perform
- **ViewModel**: Implements actions and manages state, delegates to services
- **Two providers**: `uiStateProvider` for reactive state, `actionsProvider` for user interactions

See `lib/features/tracing/` for the reference implementation.

## Setup

1. Get your Grafana Cloud Faro collector URL

2. There are two ways to configure the Faro collector URL:

   ### Option 1: Using api-config.json (Recommended)

   a. Create an `api-config.json` file in the example directory manually with:

   ```json
   {
     "FARO_COLLECTOR_URL": "https://your-collector-url"
   }
   ```

   OR run the provided script to create it:

   ```bash
   // From the root of the repo
   FARO_COLLECTOR_URL=https://your-collector-url ./tool/create-api-config-file.sh
   ```

   b. Run the example app with:

   ```bash
   flutter run --dart-define-from-file api-config.json
   ```

   ### Option 2: Using direct dart-define

   Run the example app with the environment configuration directly:

   ```bash
   flutter run --dart-define=FARO_COLLECTOR_URL=https://your-collector-url
   ```

## Features Demonstrated

The example app showcases various Faro SDK features:

### Network Monitoring

- HTTP GET/POST requests with success and failure scenarios
- Automatic tracking of network requests

### Error Tracking

- Error and exception handling
- Custom error reporting
- ANR (Application Not Responding) detection

### Performance Monitoring

- Custom measurements
- Event duration tracking
- CPU and memory usage monitoring
- App startup time tracking

### Custom Events

- Custom event logging
- Custom measurements
- Warning level logs

### Navigation Tracking

- Automatic page view tracking
- Navigation observer integration

## Implementation Details

Key implementation features shown in this example:

1. SDK Initialization

   - Proper configuration setup
   - Environment-based collector URL
   - Offline storage configuration

2. Widget Integration

   - FaroUserInteractionWidget usage
   - FaroNavigationObserver setup
   - FaroAssetBundle integration

3. Error Handling
   - Exception capture
   - Error boundary setup
   - ANR detection configuration

## Testing Features

The app provides interactive buttons to test various SDK features:

- Network requests (success/fail)
- Custom events and measurements
- Error generation
- ANR simulation
- Performance tracking

For more information about the Faro SDK, visit the [Grafana Faro documentation](https://grafana.com/docs/faro/latest/).
