# Faro Flutter SDK Reference

## Getting Started

The Faro Flutter SDK enables real-time observability for your Flutter applications by collecting logs, errors, performance metrics, and user interactions. This data is sent to Grafana Cloud or your self-hosted Grafana Alloy instance for monitoring and analysis.

> **Note:** Grafana Frontend Observability is built for web applications — there is currently no official mobile observability product from Grafana. This SDK enables mobile telemetry collection using the Faro protocol. Session tracking and error monitoring work similarly to web applications, and all telemetry data is stored in Loki/Tempo for custom dashboards and queries in Grafana.

### Installation

Add the following dependency to your `pubspec.yaml`:

```yml
dependencies:
  faro: ^<latest_version>
```

### Choose Your Setup Method

You have two options for collecting Faro telemetry data:

#### Option 1: Grafana Cloud Frontend Observability

If you're using Grafana Cloud, you can use the Frontend Observability configuration to get your collector endpoint. Note that Frontend Observability is designed for web RUM, but the collector endpoint works the same for mobile telemetry:

1. Navigate to your **Grafana Cloud instance**
2. Go to **Frontend Observability** in the left sidebar
3. Click **Create New** or select an existing application
4. In the **Add Faro to your application/Web SDK Config** section, you'll find:
   - **Faro Endpoint URL**: This is your `collectorUrl`

> **Tip**: The API key is also the last segment of your Faro endpoint URL

#### Option 2: Self-Hosted with Grafana Alloy

For self-hosted setups:

1. Set up a [Grafana Alloy](https://grafana.com/docs/alloy/latest/configure/) instance
2. Configure the [faro.receiver component](https://grafana.com/docs/alloy/latest/reference/components/faro/faro.receiver/#server-block)
3. Use the receiver's HTTP endpoint as your `collectorUrl`
4. Generate an API key for authentication

### Initialize Faro in Your App

Add this code to your Flutter app's main function:

```dart
import 'dart:io';
import 'package:faro/faro.dart';

void main() {
  // Enable HTTP request tracking — must be set before any HTTP calls are made
  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);

  Faro().runApp(
    optionsConfiguration: FaroConfig(
      appName: "my-flutter-app",
      appVersion: "1.0.0",                // optional — resolved from pubspec.yaml if omitted
      appEnv: "production",
      apiKey: "your-api-key-here",
      collectorUrl: "https://faro-collector-url-here/collect/12345",
      collectorHeaders: {
        // Optional: Additional headers for the collector.
        // Not needed for Grafana Cloud.
        "Custom-Header": "value"
      },
      // Many more options available — see Configuration Reference below
    ),
    appRunner: () => runApp(
      FaroAssetTracking(                  // tracks asset loading times and sizes
        child: FaroUserInteractionWidget( // tracks user taps and gestures
          child: MyApp()
        )
      )
    ),
  );
}

// Add the navigation observer to track screen changes:

// MaterialApp
MaterialApp(
  navigatorObservers: [FaroNavigationObserver()],
  // ...
);

// GoRouter
GoRouter(
  observers: [FaroNavigationObserver()],
  // ...
);
```

### Next Steps

- **Send custom telemetry**: Use `Faro().pushEvent()`, `Faro().pushLog()`, and other methods — see [Custom Telemetry](#custom-telemetry)
- **Create distributed traces**: Use `Faro().startSpan()` to trace operations across your app — see [Distributed Tracing](#distributed-tracing). Note that HTTP requests are automatically traced if you set up `FaroHttpOverrides` as shown above.
- **Explore the telemetry data**: Use **Tempo** for traces and **Loki** for everything else in any Grafana dashboard

---

## Automatic Event Metadata

Every event captured by Faro includes rich metadata to give you complete context about your app's performance and user behavior.

### Application Context

- **App Information**: Name, version, and environment (dev/staging/production)
- **View Information**: Current screen and navigation state
- **Session Information**: Unique session tracking and user journey mapping
- **Dart Version**: Flutter and Dart runtime information

### Device & System Information

- **Operating System**: iOS/Android version and device model
- **Device Specifications**: Memory, CPU architecture, and hardware details
- **User Information**: Optional user ID, username, email, and custom attributes
- **User Persistence**: Automatically restore user identity across app restarts for consistent session tracking

### Default Session Attributes

Every telemetry event automatically includes these session attributes:

| Attribute             | Description                 | iOS Example          | Android Example       |
| --------------------- | --------------------------- | -------------------- | --------------------- |
| `dart_version`        | Dart runtime version        | `3.10.1 (stable)...` | `3.10.1 (stable)...`  |
| `device_os`           | Operating system            | `iOS`                | `Android`             |
| `device_os_version`   | OS version                  | `17.0`               | `15`                  |
| `device_os_detail`    | Detailed OS info            | `iOS 17.0`           | `Android 15 (SDK 35)` |
| `device_manufacturer` | Manufacturer                | `apple`              | `samsung`             |
| `device_model`        | Raw model identifier        | `iPhone16,1`         | `SM-A155F`            |
| `device_model_name`   | Human-readable model        | `iPhone 15 Pro`      | `SM-A155F`\*          |
| `device_brand`        | Device brand                | `iPhone`             | `samsung`             |
| `device_is_physical`  | Physical or emulator (bool) | `true`               | `true`                |
| `device_id`           | Unique device ID            | `uuid`               | `uuid`                |

> \*Android does not provide a mapping from model codes to marketing names, so `device_model_name` equals `device_model`.

### SDK Metadata

In addition to session attributes, every telemetry payload includes SDK identification via the `meta.sdk` object. These values are set automatically and cannot be changed by the user.

| Field              | Description       | Example              |
| ------------------ | ----------------- | -------------------- |
| `meta.sdk.name`    | SDK identifier    | `faro-mobile-flutter`|
| `meta.sdk.version` | SDK version       | `0.12.0`             |

In Grafana Cloud Frontend Observability, these appear as `sdk_name` and `sdk_version` in the structured metadata of each telemetry event.

---

## Performance Monitoring

### Mobile Vitals

CPU usage and memory usage monitoring are **enabled by default**. ANR detection and refresh rate tracking are disabled by default. The interval for how often the vitals are sent defaults to 30 seconds.

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    cpuUsageVitals: true,          // default: true
    memoryUsageVitals: true,       // default: true
    anrTracking: false,            // default: false
    refreshRateVitals: false,      // default: false
    fetchVitalsInterval: const Duration(seconds: 30),  // default: 30 seconds
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

### Cold/Warm Start

App startup times are automatically captured and sent as events.

---

## Exception & Error Tracking

### Automatic Error Capture

- **Flutter Errors**: Automatic capture of all Flutter framework errors (enabled by default)
- **Dart Exceptions**: Unhandled exceptions captured automatically
- **Error Context**: Complete stack traces with device and session context

#### Enable/Disable Flutter Error Reporting

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    enableFlutterErrorReporting: true,   // default: true
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

#### Enable Crash Reporting

Enable native crash report capture:

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    enableCrashReporting: false,  // default: false
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

### Custom Error Reporting

```dart
Faro().pushError(
  type: 'checkout_error',
  value: 'Payment declined',
  stacktrace: stackTrace,
  context: {'order_id': '12345', 'payment_method': 'credit_card'},
);
```

---

## User Identity & Session Tracking

Associate telemetry with specific users for better debugging and analytics.

### Setting User Identity

```dart
// Set user after authentication
Faro().setUser(FaroUser(
  id: 'user-123',
  username: 'john.doe',
  email: 'john@example.com',
  attributes: {
    'role': 'admin',
    'organization': 'acme-corp',
  },
));

// Clear on logout
Faro().setUser(FaroUser.cleared());
```

### User Persistence

By default, user data is persisted between app sessions. This ensures early telemetry events (like `appStart`) include user identification, even before your authentication flow completes.

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    persistUser: true, // default: true
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

| Scenario                                             | Result                                                  |
| ---------------------------------------------------- | ------------------------------------------------------- |
| First app run, no login                              | No user (nothing persisted)                             |
| User logs in → `setUser(user)` called                | User persisted                                          |
| Next app start                                       | Persisted user auto-restored; early events include user |
| User logs out → `setUser(FaroUser.cleared())` called | Persisted user cleared                                  |

### Initial User in Config

For apps that know the user at startup (e.g., from cached credentials), you can set the user directly in the config:

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    initialUser: FaroUser(
      id: 'known-user-id',
      username: 'cachedUser',
    ),
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

**Precedence rules:**

1. If `initialUser` is provided → use it (and persist if persistence enabled)
2. Else if persisted user exists → restore it
3. Else → no user

To explicitly clear any persisted user on app start, use the sentinel value:

```dart
initialUser: FaroUser.cleared(), // Start with no user, ignore persisted data
```

---

## User Interaction & Navigation

### Navigation Tracking

Add the Faro Navigator Observer to track screen changes and send `view_changed` events:

```dart
// MaterialApp
MaterialApp(
  navigatorObservers: [FaroNavigationObserver()],
);

// GoRouter
GoRouter(
  observers: [FaroNavigationObserver()],
);
```

### User Interactions Widget

Add the Faro User Interactions Widget at the root level to track user interactions (tap, click, etc.):

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(/* ... */),
  appRunner: () => runApp(
    const FaroUserInteractionWidget(child: MyApp())
  ),
);
```

### Asset Bundle Tracking

Track asset loading times and sizes. Each asset load sends an `Asset-load` event with the following attributes:

| Attribute  | Description                       | Example                    |
| ---------- | --------------------------------- | -------------------------- |
| `name`     | Asset key (full path)             | `assets/images/logo.png`   |
| `size`     | Size in bytes                     | `24576`                    |
| `duration` | Load time in milliseconds         | `12`                       |

```dart
appRunner: () => runApp(
  FaroAssetTracking(
    child: const FaroUserInteractionWidget(child: MyApp())
  )
),
```

---

## User Actions

Track end-to-end user interactions by grouping all related telemetry (logs, events, exceptions, traces) under a single action context. User actions let you follow complete user journeys and understand exactly what happened during a specific interaction.

### Overview

A user action represents a meaningful user interaction, such as tapping a button, submitting a form, or starting a checkout flow. When a user action is active, all telemetry generated during its lifetime is automatically enriched with action context (`action.name` and `action.id`), making it easy to correlate signals in Grafana.

Only one user action can be active at a time. If you call `startUserAction()` while another action is running, it returns `null`.

### Starting a User Action

```dart
final action = Faro().startUserAction(
  'checkout-flow',
  attributes: {'product': 'premium', 'price': '99.99'},  // optional
  options: StartUserActionOptions(                       // optional
    importance: UserActionConstants.importanceCritical,
  ),
);

// From here, all telemetry (logs, events, HTTP requests, exceptions)
// is automatically tagged with this action
await processCheckout();
// The action ends automatically — no manual cleanup needed
```

### Checking the Active Action

```dart
final action = Faro().getActiveUserAction();
if (action != null) {
  print('Active: ${action.name}, state: ${action.getState()}');
}
```

### Action Lifecycle

User actions follow an automatic lifecycle managed by the SDK:

1. **Started** — The action is created and begins buffering telemetry. A 100ms follow-up timer starts.
2. **Activity resets the timer** — Each qualifying signal (for example: UI
   build/render activity, navigation, or pending operation start)
   resets the 100ms timer, keeping the action alive longer.
3. **Halted** — If there are still pending operations when the 100ms timer
   expires, the action enters a halted state and waits up to 10 seconds for
   them to complete.
4. **Ended** — The action completed successfully. All buffered telemetry is flushed with action context enrichment.
5. **Cancelled** — No qualifying activity occurred within 100ms, or a halted action timed out. Buffered telemetry is flushed _without_ action context.

### What Keeps an Action Alive

The following lifecycle signals are consumed by the controller:

| Signal                            | Source                                     | Effect / Requirement                         |
| --------------------------------- | ------------------------------------------ | -------------------------------------------- |
| UI build/render activity          | Internal monitor                           | Activity signal. Automatic when Faro is initialized |
| Navigation push/pop/replace       | `FaroNavigationObserver`                   | Activity signal. Must be added to `navigatorObservers` |
| HTTP pending operation start      | `HttpTrackingClient` / `FaroHttpOverrides` | `pendingStart`; activity signal. Must be enabled |
| HTTP pending operation end        | `HttpTrackingClient` / `FaroHttpOverrides` | `pendingEnd`; closes a pending operation     |
| Asset/resource load               | `FaroAssetTracking`                        | Activity signal; must wrap widget subtree    |
| Marker-based pending start (span) | Any span with `UserActionConstants.pendingOperationKey: true` | `pendingStart` for custom async work         |
| Marker-based pending end (span)   | Same marker-based span                     | `pendingEnd`; can finish halted action       |

> **Important:** Navigation, HTTP, asset-resource, and marker-based span
> signals are opt-in integrations. UI build/render signals are automatic but
> intentionally bounded to one signal per UI activity burst (burst closes after
> 100ms of UI quiet time), so continuously animating widgets do not keep an
> action alive indefinitely. To disable UI build/render monitoring entirely,
> set `enableUiActivityMonitoring: false` in `FaroConfig`; note that actions
> relying solely on UI rebuilds will then be cancelled.

### Extending a User Action with Custom Pending Spans

If you have custom async work that should keep a user action alive, mark the
span with `UserActionConstants.pendingOperationKey: true`.

```dart
final span = Faro().startSpanManual(
  'db.sync',
  attributes: {
    UserActionConstants.pendingOperationKey: true,
    'sync.type': 'background',
  },
);

try {
  await syncDatabase();
  span.setStatus(SpanStatusCode.ok);
} catch (error, stackTrace) {
  span.setStatus(SpanStatusCode.error, message: error.toString());
  span.recordException(error, stackTrace: stackTrace);
} finally {
  span.end();
}
```

This does not reopen buffering in halted state. Instead, if a marked span
starts while the action is still in `started`, the action can enter `halted`
and wait (up to 10s) for that operation to finish before finalizing.

### Parameters

| Parameter    | Type                      | Description                                                    |
| ------------ | ------------------------- | -------------------------------------------------------------- |
| `name`       | `String`                  | Human-readable name for the action (e.g., `"checkout-button"`) |
| `attributes` | `Map<String, String>?`    | Optional custom attributes attached to the action              |
| `options`    | `StartUserActionOptions?` | Optional configuration (see below)                             |

### StartUserActionOptions

| Property      | Type     | Default         | Description                                                                           |
| ------------- | -------- | --------------- | ------------------------------------------------------------------------------------- |
| `triggerName` | `String` | `"faroApiCall"` | How the action was initiated (e.g., `"pointerdown"`, `"keydown"`, or a custom source) |
| `importance`  | `String` | `"normal"`      | Importance level: `"normal"` or `"critical"`                                          |

### Action States

| State       | Description                                                        |
| ----------- | ------------------------------------------------------------------ |
| `started`   | Action is active, buffering telemetry                              |
| `halted`    | Waiting for pending operations to complete (up to 10s)              |
| `ended`     | Completed successfully — telemetry enriched with action context    |
| `cancelled` | No valid activity detected — telemetry sent without action context |

### Telemetry Enrichment

When a user action ends successfully, all captured telemetry items (events, logs, exceptions) include an `action` field:

```json
{
  "action": {
    "name": "checkout-flow",
    "parentId": "abc123"
  }
}
```

Trace spans created during the action are enriched with span attributes:

- `faro.action.user.name` — the action name
- `faro.action.user.parentId` — the action ID

---

## HTTP Network Tracking

Automatically capture detailed network information:

- **Request Duration**: Complete timing from start to finish
- **Success/Failure Rates**: Track network reliability

```dart
// Must be set before any HTTP calls are made (top of main)
HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);
```

> **Important**: HTTP tracking only captures requests made from the Flutter/Dart layer (using packages like `http`, `dio`, etc.). Native HTTP calls made directly from Android/iOS code are not tracked.

---

## Custom Telemetry

### Custom Events

```dart
Faro().pushEvent('purchase_completed', attributes: {
  'product_id': '123',
  'price': '29.99',
  'category': 'premium',
});
```

> **Note**: For typed attributes (int, double, bool), use distributed tracing spans instead — see [Distributed Tracing](#distributed-tracing).

### Custom Logs

```dart
Faro().pushLog(
  "User completed onboarding",
  level: LogLevel.info,
  context: {"user_type": "premium", "onboarding_version": "v2"},
);
```

**Available Log Levels:**

- `LogLevel.trace` - Very detailed diagnostic information
- `LogLevel.debug` - Debugging information
- `LogLevel.info` - Informational messages
- `LogLevel.log` - Generic log messages
- `LogLevel.warn` - Warning messages
- `LogLevel.error` - Error messages

### Custom Measurements

```dart
Faro().pushMeasurement(
  {'checkout_duration_ms': 4500, 'items_count': 3},
  'checkout_metrics',
);
```

### Capturing Event Duration

Use distributed tracing spans to capture operation duration:

```dart
await Faro().startSpan('checkout_duration', (span) async {
  span.setAttribute('result', 'success');
  await completeCheckout();
});
```

> **Deprecated**: `markEventStart()` / `markEventEnd()` are legacy APIs and
> will be removed in a future major version. Use `startSpan()` (or
> `startSpanManual()` when you need manual lifecycle control) instead.
>
> If your goal is to correlate all telemetry for a user interaction, use
> `startUserAction()` as an alternative.

---

## Distributed Tracing

Create detailed traces of operations across your app with automatic parent-child span relationships.

### Automatic Span Management (Recommended)

Use `startSpan()` for most tracing needs — it automatically handles span lifecycle and error reporting:

```dart
// Basic span creation with typed attributes
// Errors are handled automatically — the span status is set to error
// and the exception is recorded, so no manual try/catch needed
final result = await Faro().startSpan('process_order', (span) async {
  span.addEvent('Validation started');
  final order = await validateAndSubmitOrder(cart);
  return order.id;
}, attributes: {
  'cart_size': 3,                 // int — enables numeric queries
  'express_delivery': true,       // bool
});

// Nested spans are automatically linked
await Faro().startSpan('parent_operation', (parentSpan) async {
  parentSpan.setAttributes({
    'operation_id': 123,          // int
    'priority': 'high',           // String
  });

  final data = await fetchData();

  return await Faro().startSpan('child_operation', (childSpan) async {
    childSpan.setAttributes({
      'data_size': data.length,   // int — preserves type for querying
      'processing_rate': 0.95,    // double
    });
    return await processData(data);
  });
});

// Manual parent span — useful for custom span hierarchies
final rootSpan = Faro().startSpanManual('batch_operation');

final futures = items.map((item) =>
  Faro().startSpan('process_item', (span) async {
    span.setAttribute('item_id', item.id);
    return await processItem(item);
  }, parentSpan: rootSpan) // <-- explicitly sets parent span
);

final results = await Future.wait(futures);
rootSpan.end(); // Don't forget to end the manual span
```

### Manual Span Control

Use `startSpanManual()` when you need precise control over span lifecycle:

```dart
final span = Faro().startSpanManual('background_task',
  attributes: {'task_id': 123});

try {
  await performLongRunningTask();
  span.setStatus(SpanStatusCode.ok);
} catch (e) {
  span.setStatus(SpanStatusCode.error, message: e.toString());
  span.addEvent('Task failed', attributes: {'error': e.toString()});
} finally {
  span.end(); // Always remember to end manual spans
}
```

### Active Span Access

Access the currently active span from anywhere in your code:

```dart
void logImportantEvent(String message) {
  final activeSpan = Faro().getActiveSpan();
  if (activeSpan != null) {
    activeSpan.addEvent('important_event',
      attributes: {'message': message});
  }
}

// Usage within a traced operation
await Faro().startSpan('main_operation', (span) async {
  await doSomeWork();
  logImportantEvent('Work completed'); // Adds event to active span
});
```

### Timer & Async Callback Behavior

When using `startSpan()`, the `contextScope` parameter controls how timer and stream callbacks relate to the parent span.

#### Default: Timer Callbacks Start New Traces

By default (`ContextScope.callback`), spans are deactivated from context when the callback completes. Timer or stream callbacks that fire _after_ the callback has completed will start their own independent traces:

```dart
await Faro().startSpan('parent-operation', (parentSpan) async {
  Timer.periodic(Duration(seconds: 30), (_) {
    // Starts a NEW trace because parent was deactivated when callback ended
    Faro().startSpan('periodic-check', (span) async {
      await performHealthCheck();
    });
  });

  await doMainWork();
}); // Parent span deactivated here
```

#### Keeping Span Active for Timer Callbacks

If you want timer callbacks to inherit the parent span (same trace), use `ContextScope.zone`:

```dart
await Faro().startSpan('long-running-operation', (parentSpan) async {
  Timer.periodic(Duration(seconds: 5), (_) {
    Faro().startSpan('progress-update', (span) async {
      await reportProgress(); // Same traceId as parent
    });
  });

  await doWork();
}, contextScope: ContextScope.zone);
```

#### Explicit New Trace with Span.noParent

For explicit control, use `Span.noParent` to start a fresh trace regardless of context:

```dart
Faro().startSpan('independent-operation', (span) async {
  await doSomething();
}, parentSpan: Span.noParent); // Always starts new trace
```

#### Summary

| Scenario                          | Result                            |
| --------------------------------- | --------------------------------- |
| Default (`ContextScope.callback`) | Timer callbacks → new trace       |
| `ContextScope.zone`               | Timer callbacks → child of parent |
| `parentSpan: Span.noParent`       | Always new trace (explicit)       |

The `parentSpan` parameter supports three values:

- **Not provided / null**: Uses active span from zone context
- **`Span.noParent`**: Explicitly starts a new root trace
- **Specific `Span` instance**: Uses that span as parent

### Span Operations

```dart
// Add typed attributes — supports String, int, double, and bool
span.setAttribute('key', 'string value');
span.setAttribute('count', 42);                    // int
span.setAttribute('price', 19.99);                // double
span.setAttribute('is_active', true);             // bool

// Set multiple typed attributes at once
span.setAttributes({
  'user_id': 'user-123',           // String
  'account_count': 5,              // int
  'balance': 1234.56,              // double
  'is_premium': true,              // bool
});

// Add events with typed attributes
span.addEvent('Processing started');
span.addEvent('Checkpoint reached', attributes: {
  'progress': 50,                  // int
  'completion_rate': 0.5,          // double
  'on_track': true,                // bool
});

// Set span status (startSpan() handles this automatically)
span.setStatus(SpanStatusCode.ok);
span.setStatus(SpanStatusCode.error, message: 'Something went wrong');

// Record exceptions
span.recordException(exception, stackTrace: stackTrace);

// Access the W3C traceparent header value (for custom trace propagation)
final traceparent = span.traceparent;
// e.g. '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'
```

> **Typed Attributes**: Span attributes preserve their original types (int, double, bool, String) when sent via OTLP. This enables proper numeric querying and bucketing in Grafana/Tempo — for example, you can filter traces where `account_count > 10` or create histograms of `balance` values.

### Span Features

- **Automatic Session Tracking**: All spans include session IDs for correlation
- **Zone-based Context**: Proper parent-child relationships across async boundaries
- **Error Handling**: Automatic span status updates when exceptions occur
- **Typed Attributes**: Add business context with preserved types (int, double, bool, String) — enables numeric querying and bucketing in Grafana
- **Event Logging**: Record important events within span timelines with typed attributes

---

## WebView Tracing

When your Flutter app opens a web page in a WebView, `FaroWebViewBridge` propagates the distributed trace and session context across the boundary so the web app's telemetry appears as part of the same user journey.

### How It Works

1. **Flutter → Web**: `instrumentedUrl()` starts a span and appends `traceparent`, `session.parent_id`, and `session.parent_app` as query parameters. The web app reads these to continue the trace and identify the originating mobile session.
2. **Web → Flutter**: The web app sends its Faro session ID back (e.g. via a JavaScript channel). You call `linkChildSession()` to push a `session.linked` event that correlates the two sessions.
3. **Span lifecycle**: Call `end()` when the WebView is dismissed so the span duration reflects how long the user spent in the WebView.

### Basic Usage

```dart
import 'package:faro/faro.dart';

final bridge = FaroWebViewBridge();

// 1. Decorate the URL and start the WebView span
final url = bridge.instrumentedUrl(Uri.parse('https://my-web-app.com/login'));
webViewController.loadRequest(url);

// 2. When the web app sends back its session info (e.g. via JS channel):
bridge.linkChildSession(sessionId: webSessionId, appName: webAppName);

// 3. When the WebView is dismissed (typically in dispose()):
bridge.end();
```

### Full Widget Example

```dart
class MyWebViewPage extends StatefulWidget {
  const MyWebViewPage({required this.url, super.key});
  final Uri url;

  @override
  State<MyWebViewPage> createState() => _MyWebViewPageState();
}

class _MyWebViewPageState extends State<MyWebViewPage> {
  late final WebViewController _controller;
  late final FaroWebViewBridge _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = FaroWebViewBridge();
    final instrumentedUrl = _bridge.instrumentedUrl(widget.url);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MyBridge', onMessageReceived: (msg) {
        final data = jsonDecode(msg.message) as Map<String, dynamic>;
        if (data['type'] == 'faro_session') {
          _bridge.linkChildSession(
            sessionId: data['session_id'] as String,
            appName: data['app_name'] as String?,
          );
        }
      })
      ..loadRequest(instrumentedUrl);
  }

  @override
  void dispose() {
    _bridge.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: WebViewWidget(controller: _controller));
  }
}
```

### API Reference

#### `instrumentedUrl(Uri url, {String spanName = 'WebView'})`

Returns a new `Uri` with three query parameters appended:

| Parameter           | Description                                    |
| ------------------- | ---------------------------------------------- |
| `traceparent`       | W3C Trace Context header for trace propagation |
| `session.parent_id` | The current Flutter Faro session ID            |
| `session.parent_app`| The Flutter app name from Faro config          |

Starts a manual span named `spanName` (default `'WebView'`). If called while a previous span is still active, the previous span is ended with an error status.

#### `linkChildSession({required String sessionId, String? appName})`

Pushes a `session.linked` event with attributes:

| Attribute           | Description                          |
| ------------------- | ------------------------------------ |
| `session.child_id`  | The web app's Faro session ID        |
| `session.child_app` | The web app's name (optional)        |

The parent session info is automatically included via Faro's session context on the event.

#### `end({SpanStatusCode status = SpanStatusCode.ok, String? message})`

Ends the active WebView span. Safe to call multiple times or without a prior `instrumentedUrl()` call.

### Web-Side Setup

The web app needs to read the query parameters from the URL. For a Faro Web SDK app, read `traceparent` and set it as the root OpenTelemetry context, and read `session.parent_id` / `session.parent_app` to store as session attributes.

See `example/webview_demo/` in this repository for a complete React reference implementation.

### Session Correlation in Grafana

The bidirectional session linking enables lookups in both directions:

| Starting from       | How to find the linked session                                                  |
| ------------------- | ------------------------------------------------------------------------------- |
| Web session         | Filter on `session.parent_id` attribute to find the originating mobile session  |
| Mobile session      | Look for `session.linked` events; read `session.child_id` for spawned web sessions |

---

## Configuration Reference

### Batching Configuration

Telemetry is batched and sent to the server in a single request. Configure the batch size and send interval:

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    batchConfig: BatchConfig(
      payloadItemLimit: 30,                           // default: 30
      sendTimeout: const Duration(milliseconds: 300), // default: 300ms
      enabled: true,                                  // default: true
    ),
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

### Max In-Flight Requests

Controls the maximum number of simultaneous HTTP requests to the collector. If the limit is reached, new telemetry payloads are dropped until an in-flight request completes. This prevents flooding the network when large bursts of telemetry are generated.

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    maxBufferLimit: 30, // default: 30
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

### Custom Session Attributes

Add custom attributes to all session data. These attributes are merged with the automatically collected default attributes (SDK version, Dart version, device info, etc.):

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    sessionAttributes: {
      'team': 'mobile',
      'department': 'engineering',
      'environment': 'production',
      'cost_center': 1234,           // int — preserved for numeric queries
      'is_beta_user': true,          // bool — preserved as boolean
    },
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

**Notes:**

- Custom attributes are merged with default attributes (like `device_os`, `device_model`, etc.)
- Default attributes take precedence if there are naming conflicts
- Session attributes are included in all telemetry data (logs, events, exceptions, traces)
- **Type handling**: Session attributes support typed values (String, int, double, bool):
  - **Faro session** (`meta.session.attributes`): Values are stringified per Faro protocol requirements
  - **Span resources** (`resource.attributes`): Types are preserved (int, double, bool, String), enabling numeric queries and filtering in trace backends

### Session Sampling

Control what percentage of sessions send telemetry data. Useful for managing costs and reducing traffic for high-volume applications.

#### Fixed Sampling Rate

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    sampling: SamplingRate(0.5), // Sample 50% of sessions (default: 100% if omitted)
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

| Sampling            | Behavior                                       |
| ------------------- | ---------------------------------------------- |
| Not provided        | All sessions sampled (default — send all data) |
| `SamplingRate(1.0)` | All sessions sampled (100%)                    |
| `SamplingRate(0.5)` | 50% of sessions sampled                        |
| `SamplingRate(0.1)` | 10% of sessions sampled                        |
| `SamplingRate(0.0)` | No sessions sampled (no data sent)             |

#### Dynamic Sampling

Use `SamplingFunction` for dynamic sampling decisions based on session context:

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    appName: 'MyApp',
    appEnv: 'production',
    apiKey: 'xxx',
    collectorUrl: 'https://...',
    sampling: SamplingFunction((context) {
      // Sample all beta users
      if (context.meta.user?.attributes?['role'] == 'beta') {
        return 1.0;
      }
      // Sample 10% of production sessions
      if (context.meta.app?.environment == 'production') {
        return 0.1;
      }
      // Sample all in development
      return 1.0;
    }),
  ),
  appRunner: () => runApp(const MyApp()),
);
```

**How it works:**

- The sampling decision is made once per session at initialization time
- When a session is not sampled, all telemetry (events, logs, exceptions, measurements, traces) is silently dropped
- A debug log is emitted when a session is not sampled, for transparency during development
- Invalid return values (< 0.0 or > 1.0) are clamped to the valid range

**Available context:**

| Property           | Access Pattern                     | Description                              |
| ------------------ | ---------------------------------- | ---------------------------------------- |
| Session ID         | `context.meta.session?.id`         | Unique session identifier                |
| Session attributes | `context.meta.session?.attributes` | Custom sessionAttributes from config     |
| User ID            | `context.meta.user?.id`            | User ID (from initialUser or persisted)  |
| User attributes    | `context.meta.user?.attributes`    | Custom user attributes                   |
| App name           | `context.meta.app?.name`           | App name from config                     |
| App environment    | `context.meta.app?.environment`    | App environment from config              |
| App version        | `context.meta.app?.version`        | App version (from config or PackageInfo) |
| SDK version        | `context.meta.sdk?.version`        | Faro SDK version                         |

**Notes:**

- Sampling is head-based: the decision is made at SDK initialization and remains consistent for the entire session
- This aligns with [Faro Web SDK sampling behavior](https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/instrument/sampling/)

**Use cases:**

- Sample all beta testers while sampling only 10% of regular users
- Different sampling rates per environment (100% in dev, 10% in production)
- A/B testing with different sampling for different user segments
- Sampling based on custom session attributes (team, feature flags, etc.)
- Remote-controlled sampling via feature flags — fetch your sampling rate from a remote config service at startup and pass it to `SamplingRate()` or use it inside a `SamplingFunction`

### Data Collection Control

Enable or disable data collection at runtime. This setting is automatically persisted across app restarts.

```dart
// Check current state
bool isEnabled = Faro().enableDataCollection;

// Disable data collection (automatically persisted)
Faro().enableDataCollection = false;
```

**Persistence behavior:**

- **Default State**: Data collection is enabled by default on first app launch
- **Automatic Persistence**: Any changes are automatically saved to device storage
- **Cross-Session**: The setting persists across app restarts, device reboots, and app updates
- **Storage**: Uses SharedPreferences on both iOS and Android

**Use cases:**

- **Privacy Controls**: Allow users to opt-out of data collection
- **Compliance**: Meet regulatory requirements for data collection consent

---

## Offline Support

Offline support is opt-in. Add `OfflineTransport` to the transports list **before** calling `runApp`:

```dart
Faro().transports.add(OfflineTransport(
  maxCacheDuration: const Duration(days: 3), // how long to keep cached data
));

await Faro().runApp(
  optionsConfiguration: FaroConfig(/* ... */),
  appRunner: () => runApp(const MyApp()),
);
```

Once enabled:

- **Offline Event Storage**: Events are automatically cached to disk when the device is offline
- **Smart Synchronization**: Cached data is sent automatically when connectivity is restored
- **Cache Expiry**: Cached events older than `maxCacheDuration` are discarded on sync

---

## Data Destinations

Your Faro telemetry data can be sent to:

- **Grafana Cloud Frontend Observability**: Purpose-built RUM visualization
- **Grafana Alloy**: Self-hosted collection and forwarding

---

## Need Help?

- Review how the example app uses Faro in the [`/example`](../example/) directory
- Visit [Grafana's Frontend Observability docs](https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/) for more information
