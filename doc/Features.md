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
  message: "User completed onboarding",
  level: "info",
  context: {"user_type": "premium", "onboarding_version": "v2"}
);
```

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
