# 🚀 Faro Flutter SDK Features

The Grafana Faro Flutter SDK provides comprehensive real user monitoring (RUM) capabilities for your mobile applications. Here's everything you can track and monitor out of the box:

## 📊 Automatic Event Metadata

Every event captured by Faro includes rich metadata to give you complete context about your app's performance and user behavior:

### 📱 Application Context

- **App Information**: Name, version, and environment (dev/staging/production)
- **View Information**: Current screen and navigation state
- **Session Information**: Unique session tracking and user journey mapping
- **Dart Version**: Flutter and Dart runtime information

### 🔧 Device & System Information

- **Operating System**: iOS/Android version and device model
- **Device Specifications**: Memory, CPU architecture, and hardware details
- **User Information**: Optional user ID, username, email, and custom attributes
- **User Persistence**: Automatically restore user identity across app restarts for consistent session tracking

### 📋 Default Session Attributes

Every telemetry event automatically includes these session attributes:

| Attribute             | Description                 | iOS Example          | Android Example       |
| --------------------- | --------------------------- | -------------------- | --------------------- |
| `faro_sdk_version`    | SDK version                 | `0.6.0`              | `0.6.0`               |
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

## ⚡ Performance Monitoring

Get deep insights into your app's performance with automatic monitoring:

### 🧠 System Resources

- **CPU Usage**: Track processor utilization and identify performance bottlenecks
- **Memory Usage**: Monitor memory consumption and detect potential leaks
- **Cold/Warm Start**: Measure app launch times and startup performance
- **ANR Detection**: Automatically detect Application Not Responding events

> 💡 **Pro Tip**: Use performance data to identify which screens or features impact your app's responsiveness the most.

## 🐛 Exception & Error Tracking

Never miss a crash or error with comprehensive exception monitoring:

### 🚨 Automatic Error Capture

- **Flutter Errors**: Automatic capture of all Flutter framework errors
- **Dart Exceptions**: Unhandled exceptions and custom error reporting
- **Error Context**: Complete stack traces with device and session context

```dart
// Custom error reporting
Faro().pushError(
  error: customError,
  context: "User checkout process",
  stackTrace: stackTrace,
);
```

## 👤 User Identity & Session Tracking

Associate telemetry with specific users for better debugging and analytics:

### 🔑 User Identification

- **User Attributes**: Track user ID, username, and email across all telemetry
- **Automatic Persistence**: User identity is saved and restored across app restarts
- **Early Event Attribution**: Even startup events like `appStart` include user data
- **Logout Support**: Clear user identity when users log out

```dart
// Set user after authentication
Faro().setUser(FaroUser(
  id: 'user-123',
  username: 'john.doe',
  email: 'john@example.com',
));

// Clear on logout
Faro().setUser(FaroUser.cleared());
```

> 💡 **Pro Tip**: User persistence means you don't need to wait for authentication to complete before telemetry starts capturing user context on subsequent app launches.

## 📈 User Interaction & Events

Understand how users interact with your app:

### 🎯 User Journey Tracking

- **Session Start**: Automatic session initiation and management
- **Route Changes**: Track navigation patterns and user flows
- **User Interactions**: Button taps, gestures, and UI interactions
- **Custom Events**: Track business-specific events and user actions

```dart
// Track custom user events (string attributes)
Faro().pushEvent(
  name: "purchase_completed",
  attributes: {
    'product_id': '123',
    'price': '29.99',
    'category': 'premium',
  }
);

// For typed attributes (int, double, bool), use tracing spans instead:
await Faro().startSpan('purchase_completed', (span) async {
  span.setAttributes({
    'product_id': 123,        // int
    'price': 29.99,           // double
    'is_premium': true,       // bool
  });
  // ... your code
});
```

## 🌐 Network & Resource Monitoring

Monitor your app's network performance and resource loading:

### 📡 HTTP Network Tracking

Automatically capture detailed network information:

- **Request Duration**: Complete timing from start to finish
- **Success/Failure Rates**: Track network reliability

```dart
// HTTP tracking is automatic enabled when you add:
HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);
```

> ⚠️ **Important**: HTTP tracking only captures requests made from the Flutter/Dart layer (using packages like `http`, `dio`, etc.). Native HTTP calls made directly from Android/iOS code are not tracked.

### 📦 Asset Loading Performance

- **Asset Bundle Tracking**: Monitor Flutter asset loading times
- **Asset Size Monitoring**: Track the size of loaded resources
- **Loading Performance**: Identify slow-loading assets affecting user experience

## 🎨 Custom Telemetry

Extend Faro's capabilities with custom tracking:

### 📝 Custom Data Collection

- **Custom Events**: Track business logic and user workflows
- **Custom Logs**: Add contextual logging with different severity levels
- **Custom Measurements**: Monitor specific metrics important to your app
- **Custom Errors**: Report domain-specific errors and edge cases

```dart
// Custom measurements
Faro().pushMeasurement(
  name: "checkout_duration",
  value: Duration(seconds: 45).inMilliseconds.toDouble(),
  unit: "milliseconds"
);

// Custom logs with levels
Faro().pushLog(
  "User completed onboarding",
  level: LogLevel.info,
  context: {"user_type": "premium", "onboarding_version": "v2"}
);
```

## 🔗 Distributed Tracing

Create detailed traces of operations across your app with automatic parent-child span relationships:

### 🚀 Automatic Span Management

Use `startSpan()` for most tracing needs - it automatically handles span lifecycle and error reporting:

```dart
// Trace a complete operation with typed attributes
final result = await Faro().startSpan('api_request', (span) async {
  // Add more attributes within the callback if needed
  span.addEvent('Request started');

  try {
    final response = await http.get(Uri.parse('https://api.example.com/users'));
    // Status automatically set to 'ok' on success - no need to set manually
    return response.body;
  } catch (e) {
    // Status automatically set to 'error' on exception - no need to set manually
    // But you can add custom error details if needed
    span.addEvent('Request failed', attributes: {'error': e.toString()});
    rethrow;
  }
}, attributes: {
  'endpoint': '/api/users',       // String
  'timeout_seconds': 30,          // int - enables numeric queries!
  'retry_enabled': true,          // bool
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
      'data_size': data.length,   // int - preserves type for querying
      'processing_rate': 0.95,    // double
    });
    return await processData(data);
    // Span status automatically handled based on success/failure
  });
});

// Manual parent span - useful for custom span hierarchies
final rootSpan = Faro().startSpanManual('batch_operation');

// Process multiple items with the same explicit parent
final futures = items.map((item) =>
  Faro().startSpan('process_item', (span) async {
    span.setAttribute('item_id', item.id);
    return await processItem(item);
    // No manual status setting needed - handled automatically
  }, parentSpan: rootSpan) // Explicitly use rootSpan as parent
);

final results = await Future.wait(futures);
rootSpan.end(); // Don't forget to end the manual span
```

### 🎛️ Manual Span Control

Use `startSpanManual()` when you need precise control over span lifecycle:

```dart
// Manual span for event-driven or callback-based operations
final span = Faro().startSpanManual('background_task',
  attributes: {'task_id': '123'});

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

### 📍 Active Span Access

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

### 🕐 Timer & Async Callback Behavior

When using `startSpan()`, you have control over how timer and stream callbacks relate to the parent span. The `contextScope` parameter determines this behavior.

#### Default: Timer Callbacks Start New Traces

By default (`ContextScope.callback`), spans are deactivated from context when the callback completes. Timer or stream callbacks that fire _after_ the callback has completed will start their own independent traces:

```dart
await Faro().startSpan('parent-operation', (parentSpan) async {
  // This timer fires after the callback completes (30s > doMainWork duration)
  Timer.periodic(Duration(seconds: 30), (_) {
    // Starts a NEW trace because parent was deactivated when callback ended
    Faro().startSpan('periodic-check', (span) async {
      await performHealthCheck();
    });
  });

  await doMainWork(); // Takes less than 30 seconds
}); // Parent span deactivated here
```

#### Keeping Span Active for Timer Callbacks

If you want timer callbacks to inherit the parent span (same trace), use `ContextScope.zone`:

```dart
await Faro().startSpan('long-running-operation', (parentSpan) async {
  // Timer callbacks WILL be children of this span
  Timer.periodic(Duration(seconds: 5), (_) {
    Faro().startSpan('progress-update', (span) async {
      await reportProgress(); // Same traceId as parent
    });
  });

  await doWork();
}, contextScope: ContextScope.zone); // Span stays active for zone lifetime
```

#### Explicit New Trace with Span.noParent

For explicit control, use `Span.noParent` to start a fresh trace regardless of context:

```dart
// Useful inside zone-scoped spans or manual spans
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

### 🔄 Span Features

- **Automatic Session Tracking**: All spans include session IDs for correlation
- **Zone-based Context**: Proper parent-child relationships across async boundaries
- **Error Handling**: Automatic span status updates when exceptions occur
- **Typed Attributes**: Add business context with preserved types (int, double, bool, String) - enables numeric querying and bucketing in Grafana
- **Event Logging**: Record important events within span timelines with typed attributes

## 💾 Offline Support

Never lose telemetry data, even when users are offline:

### 🔄 Intelligent Caching

- **Offline Event Storage**: Automatically cache events when network is unavailable
- **Smart Synchronization**: Automatically sync cached data when connection is restored
- **Data Integrity**: Ensure no telemetry data is lost during network interruptions

## 📊 Data Destinations

Your Faro telemetry data can be sent to:

- **Grafana Cloud Frontend Observability**: Purpose-built RUM visualization
- **Grafana Alloy**: Self-hosted collection and forwarding

---

## 🚀 Get Started

Ready to add powerful observability to your Flutter app? Check out our [Getting Started Guide](./Getting%20Started.md) for step-by-step setup instructions.

For a hands-on experience, explore the [example app](../example/) which demonstrates all these features in action!
