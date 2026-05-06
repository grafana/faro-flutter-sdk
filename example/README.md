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

   a. Copy the example config file and add your collector URL:

   ```bash
   cp api-config.example.json api-config.json
   ```

   Then edit `api-config.json` with your actual collector URL:

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

   ### Option 3: Helper scripts (Quick run)

   For a faster CLI workflow, three helper scripts live in `tool/`:

   ```bash
   ./tool/list-devices.sh                      # connected devices + available emulators
   ./tool/launch-emulator.sh <emulator-id>     # boot an emulator and wait for it
   ./tool/run-example.sh -d <device-id>        # run the example app
   ```

   `run-example.sh` uses `example/api-config.json` and forwards any extra args
   to `flutter run`, e.g. `./tool/run-example.sh -d emulator-5554 --release`.

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

### WebView Tracing

- Open a React app in a WebView using `FaroWebViewBridge` which appends
  `traceparent`, `session.parent_id`, and `session.parent_app` query params
- The web app continues the native trace when making HTTP requests
- The web app reports its own Faro session ID back to Flutter, which
  calls `bridge.linkChildSession()` to push a `session.linked` event
  with `session.child_id` and `session.child_app` attributes
- Verify in Grafana Tempo that Flutter and React spans share one trace
- See [WebView Tracing Feature](#webview-tracing-feature) for setup instructions

## Implementation Details

Key implementation features shown in this example:

1. SDK Initialization
   - Proper configuration setup
   - Environment-based collector URL
   - Offline storage configuration

2. Widget Integration
   - FaroUserInteractionWidget usage
   - FaroNavigationObserver setup
   - FaroAssetTracking integration

3. Error Handling
   - Exception capture
   - Error boundary setup
   - ANR detection configuration

## QA Smoke Test Configuration

The example app supports optional QA dart-define keys that inject session
attributes and an initial user at startup, removing the need to patch source
code for automated smoke tests.

| Key | Type | Purpose |
|-----|------|---------|
| `FARO_QA_RUN_ID` | string | Adds `qa_run_id` to session attributes |
| `FARO_QA_INITIAL_USER_JSON` | stringified JSON | Sets the initial `FaroUser` |

Both keys are optional. When absent or empty, the app behaves normally.

All configuration lives in `api-config.json` and is passed via a single flag:

```bash
flutter run --dart-define-from-file api-config.json
```

### Example: api-config.json with QA fields

```json
{
  "FARO_COLLECTOR_URL": "https://your-collector-url",
  "FARO_QA_RUN_ID": "smoke-test-12345",
  "FARO_QA_INITIAL_USER_JSON": "{\"id\":\"user-123\",\"username\":\"qa-bot\",\"email\":\"qa@test.com\",\"attributes\":{\"role\":\"tester\"}}"
}
```

The user JSON value must be a stringified JSON object (escaped quotes).
Automation agents can produce this by JSON-encoding the user map into a string
value.

Non-string attribute values (booleans, numbers) in the user JSON are
automatically converted to strings to match the `FaroUser.attributes` contract.
Invalid JSON is silently ignored, falling back to the normal initial user.

## WebView Tracing Feature

The example app includes a `WebView Tracing` feature page. It opens an
external React demo app in a WebView using `FaroWebViewBridge` (from
`package:faro`), which appends `traceparent`, `session.parent_id`, and
`session.parent_app` as query parameters. The `traceparent` creates a
continuous distributed trace across native and web — the React app's
HTTP requests appear as child spans under the Flutter `WebView` span in
Grafana Tempo. The `session.parent_*` parameters enable cross-session
correlation: they let you navigate between the Flutter and web Faro
sessions in Frontend Observability, understanding the full user journey
across both environments. The web app sends its own session ID back to
Flutter via the `HandoffBridge` JS channel, and Flutter calls
`bridge.linkChildSession()` to push a `session.linked` event,
completing the bidirectional link.

### Running the WebView demo

1. Install dependencies and start the React dev server:

   ```bash
   cd example/webview_demo
   npm install
   cp .env.example .env   # edit with your Faro Web collector URL
   npm run dev
   ```

2. Add `FARO_WEBVIEW_DEMO_URL` to your `api-config.json`:

   ```json
   {
     "FARO_COLLECTOR_URL": "https://your-collector-url",
     "FARO_WEBVIEW_DEMO_URL": "http://10.0.2.2:5173"
   }
   ```

   Use `http://10.0.2.2:5173` for the Android emulator or
   `http://localhost:5173` for the iOS simulator.

3. Run the Flutter example app as usual.

### What to inspect

- A `WebView` span appears on the Flutter side, covering the full
  WebView session
- The React app's `POST /api/login` appears as a child HTTP span
  under the same trace ID in Grafana Tempo
- Both Flutter and React spans share one trace, demonstrating
  cross-boundary trace continuity
- The web app's Faro session includes `session.parent_id` and
  `session.parent_app` attributes identifying the Flutter session
  that opened it
- A `session.linked` event in the Flutter session records the web
  app's session ID (`session.child_id`) and app name
  (`session.child_app`), enabling bidirectional lookup


## Testing Features

The app provides interactive buttons to test various SDK features:

- Network requests (success/fail)
- Custom events and measurements
- Error generation
- ANR simulation
- Performance tracking

For more information about the Faro SDK, visit the [Grafana Faro documentation](https://grafana.com/docs/faro/latest/).
