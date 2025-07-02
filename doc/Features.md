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
- **User Information**: Optional user ID and custom attributes

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

## 📈 User Interaction & Events

Understand how users interact with your app:

### 🎯 User Journey Tracking

- **Session Start**: Automatic session initiation and management
- **Route Changes**: Track navigation patterns and user flows
- **User Interactions**: Button taps, gestures, and UI interactions
- **Custom Events**: Track business-specific events and user actions

```dart
// Track custom user events
Faro().pushEvent(
  name: "purchase_completed",
  attributes: {
    "product_id": "123",
    "price": 29.99,
    "category": "premium"
  }
);
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
// Trace a complete operation with initial attributes
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
  'endpoint': '/api/users',
  'method': 'GET',
  'timeout': '30s',
});

// Nested spans are automatically linked
await Faro().startSpan('parent_operation', (parentSpan) async {
  parentSpan.setAttribute('operation_id', '123');

  final data = await fetchData();

  return await Faro().startSpan('child_operation', (childSpan) async {
    childSpan.setAttribute('data_size', data.length.toString());
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

### 🔄 Span Features

- **Automatic Session Tracking**: All spans include session IDs for correlation
- **Zone-based Context**: Proper parent-child relationships across async boundaries
- **Error Handling**: Automatic span status updates when exceptions occur
- **Custom Attributes**: Add business context and metadata to spans
- **Event Logging**: Record important events within span timelines

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
