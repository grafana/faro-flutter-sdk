## Configurations

### Http Tracking

To enable tracking http requests you can override the global HttpOverrides (if you have any other overrides add them before adding FaroHttpOverrides)

```dart
  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);

```

### Mobile Vitals

Mobile Vitals such as cpu usage, memory usage & refresh rate are disabled by default.
The interval for how often the vitals are sent can also be
given (default is set to 60 seconds)

```dart
  Faro().runApp(
    optionsConfiguration: FaroConfig(
        // ...
        cpuUsageVitals: true,
        memoryUsageVitals: true,
        anrTracking: true,
        refreshrate: true,
        fetchVitalsInterval: const Duration(seconds: 60),
        // ...
    ),
    appRunner:
    //...

    )

```

### Batching Configuration

The Faro logs can be batched and sent to the server in a single request. The batch size and the interval for sending the batch can be configured.

```dart
  Faro().runApp(
    optionsConfiguration: FaroConfig(
        // ...
        batchConfig: BatchConfig(
          payloadItemLimit: 30, // default is 30
          sendTimeout: const Duration(milliseconds: 500 ), // default is 500 milliseconds
          enabled: true, // default is true

        ),
        // ...
    ),
    appRunner:
    //...

    )

```

### RateLimiting Configuration

Limit the number of concurrent requests made to the Faro server

```dart
  Faro().runApp(
    optionsConfiguration: FaroConfig(
        // ...
        maxBufferLimit: 30, // default is 30
        // ...
    ),
    appRunner:
    //...

    )

```

### Enable CrashReporting

enable capturing of app crashes

```dart
  Faro().runApp(
    optionsConfiguration: FaroConfig(
    // ...
    enableCrashReporting: false
    // ...
    ),
    appRunner:
    //...
)

```

### Enable/Disable Flutter error reporting

enable or disable reporting of Flutter and Plugin errors (default: enabled)

```dart
  Faro().runApp(
    optionsConfiguration: FaroConfig(
    // ...
    enableFlutterErrorReporting: false
    // ...
    ),
    appRunner:
    //...
)

```

Faro Navigator Observer can be added to the list of observers to get view info and also send `view_changed` events when the route changes

```dart
    return MaterialApp(
        //...
      navigatorObservers: [FaroNavigationObserver()],
      //...
      ),
```

### Faro User Interactions Widget

Add the Faro User Interactions Widget at the root level to enable the tracking of user interactions (click,tap...)

```dart
  Faro().runApp(
    optionsConfiguration: FaroConfig(
        //...
    ),
    appRunner: () => runApp(
       const FaroUserInteractionWidget(child: MyApp())
    ),
  );
```

### Faro Asset Bundle

Add the Faro Asset Bundle to track asset load info

```dart
//..
    appRunner: () => runApp(
      DefaultAssetBundle(bundle: FaroAssetBundle(), child: const FaroUserInteractionWidget(child: MyApp()))
    ),
    //..
```

### Sending Custom Events

```dart
    Faro().pushEvent(String name, {Map<String, String>? attributes})
    // example
    Faro().pushEvent("event_name")
    Faro().pushEvent("event_name", attributes:{
        attr1:"value"
    })
```

### Sending Custom Logs

```dart
Faro().pushLog(String message, {required LogLevel level, Map<String, dynamic>? context, Map<String, String>? trace})
//example
Faro().pushLog("log_message", level: LogLevel.warn)
```

**Available Log Levels:**

- `LogLevel.trace` - Very detailed diagnostic information
- `LogLevel.debug` - Debugging information
- `LogLevel.info` - Informational messages
- `LogLevel.log` - Generic log messages
- `LogLevel.warn` - Warning messages
- `LogLevel.error` - Error messages

### Sending Custom Measurements

- values can only have numeric values

```dart
    Faro().pushMeasurement(Map<String, dynamic >? values, String type)
    Faro().pushMeasurement({attr1:13.1, attr2:12},"some_measurements")
```

### Sending Custom Errors

```dart
    Faro().pushError({required type, required value, StackTrace? stacktrace,  String? context})
```

### Capturing Event Duration

To capture the duration of an event you can use the following methods

```dart
    Faro().markEventStart(String key,String name)
    // code
    Faro().markEventEnd(String key,String name, {Map<String, String>? attributes})
```

### Distributed Tracing

Create detailed traces of operations with parent-child span relationships.

#### Automatic Span Management (Recommended)

Use `startSpan()` for most tracing scenarios. It automatically handles span lifecycle, error reporting, and cleanup:

```dart
// Basic span creation with attributes as parameters
final result = await Faro().startSpan('user_action', (span) async {
  // You can add more attributes within the callback
  span.setAttribute('additional_info', 'value');

  return await performUserAction();
}, attributes: {
  'user_id': '123',
  'action_type': 'purchase',
});

// Or set all attributes within the callback
final result = await Faro().startSpan('user_action', (span) async {
  span.setAttributes({
    'user_id': '123',
    'action_type': 'purchase',
  });

  return await performUserAction();
});

// Nested spans - child spans automatically inherit parent context
await Faro().startSpan('checkout_process', (parentSpan) async {
  parentSpan.setAttribute('cart_size', '3');

  await Faro().startSpan('validate_payment', (childSpan) async {
    childSpan.setAttribute('payment_method', 'credit_card');
    return await validatePayment();
  });

  return await Faro().startSpan('process_order', (childSpan) async {
    childSpan.setAttribute('order_priority', 'high');
    return await processOrder();
  });
});

// Manual parent span - useful for custom span hierarchies
final batchSpan = Faro().startSpanManual('user_batch_operation');

// Process multiple operations with the same explicit parent
await Faro().startSpan('operation_1', (span) async {
  span.setAttribute('operation_type', 'data_sync');
  return await syncUserData();
}, parentSpan: batchSpan); // Explicitly use batchSpan as parent

await Faro().startSpan('operation_2', (span) async {
  span.setAttribute('operation_type', 'cache_refresh');
  return await refreshCache();
}, parentSpan: batchSpan); // Both operations share the same parent

batchSpan.end(); // Don't forget to end the manual span

// Error handling is automatic - no manual status setting needed
await Faro().startSpan('risky_operation', (span) async {
  try {
    return await riskyOperation();
    // Span automatically marked as successful - no need to set status manually
  } catch (e) {
    // Span automatically marked as error with exception details - no need to set status manually
    // But you can add custom error context if needed
    span.addEvent('Operation failed', attributes: {'retry_count': '3'});
    rethrow;
  }
  // Span automatically ended
}, attributes: {
  'operation_id': 'op_123',
  'timeout_seconds': '30',
});
```

#### Manual Span Management

Use `startSpanManual()` when you need explicit control over span lifecycle:

```dart
// Manual span creation - requires manual status management
final span = Faro().startSpanManual('background_task',
  attributes: {'task_id': 'bg_123'});

try {
  await performTask();
  span.setStatus(SpanStatusCode.ok);  // Manual status setting required
} catch (e) {
  span.setStatus(SpanStatusCode.error, message: e.toString());  // Manual error handling required
  span.addEvent('Task failed', attributes: {'error': e.toString()});
} finally {
  span.end(); // Must manually end the span
}

// Creating span hierarchies
final parentSpan = Faro().startSpanManual('batch_process');
final childSpan1 = Faro().startSpanManual('process_item_1', parentSpan: parentSpan);
final childSpan2 = Faro().startSpanManual('process_item_2', parentSpan: parentSpan);

// Process items...
childSpan1.end();
childSpan2.end();
parentSpan.end();
```

#### Active Span Access

Access the currently active span from anywhere in your code:

```dart
void addContextToCurrentSpan(String key, String value) {
  final activeSpan = Faro().getActiveSpan();
  if (activeSpan != null) {
    activeSpan.setAttribute(key, value);
  }
}

// Usage
await Faro().startSpan('main_operation', (span) async {
  await doSomeWork();
  addContextToCurrentSpan('work_completed', 'true'); // Adds to active span
});
```

#### Span Operations

```dart
// Add attributes
span.setAttribute('key', 'value');
span.setAttributes({'key1': 'value1', 'key2': 'value2'});

// Add events (like logs within the span)
span.addEvent('Processing started');
span.addEvent('Checkpoint reached', attributes: {'progress': '50%'});

// Set span status (optional - startSpan() handles this automatically)
span.setStatus(SpanStatusCode.ok);  // Usually not needed
span.setStatus(SpanStatusCode.error, message: 'Something went wrong');  // Optional for custom error messages

// Record exceptions
span.recordException(exception, stackTrace: stackTrace);
```

### User Management

Set user information to associate telemetry data with specific users. User data is attached to all logs, events, exceptions, and traces.

```dart
// Set user
Faro().setUser(FaroUser(
  id: '123',
  username: 'johndoe',
  email: 'johndoe@example.com',
));

// Clear user (e.g., on logout)
Faro().setUser(FaroUser.cleared());
```

#### User Persistence

By default, user data is persisted between app sessions. This ensures early telemetry events (like `appStart`) include user identification, even before your authentication flow completes.

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    persistUser: true, // default: true - persists user across app restarts
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

#### Initial User in Config

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

#### Deprecated API

The `setUserMeta()` method is deprecated. Migrate to `setUser()`:

```dart
// Old (deprecated)
Faro().setUserMeta(userId: '123', userName: 'user', userEmail: 'user@example.com');

// New
Faro().setUser(FaroUser(id: '123', username: 'user', email: 'user@example.com'));
```

### Custom Session Attributes

Add custom attributes to all session data. These attributes are merged with the automatically collected default attributes (SDK version, Dart version, device info, etc.) and are useful for:

- **Access Control**: Label-based permissions
- **Data Segmentation**: Team, department, or environment labels
- **Custom Metadata**: Any custom information about the session

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    sessionAttributes: {
      'team': 'mobile',
      'department': 'engineering',
      'environment': 'production',
      'cost_center': '1234',
    },
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

**Important Notes:**

- Custom attributes are merged with default attributes (like `faro_sdk_version`, `device_os`, `device_model`, etc.)
- Default attributes take precedence if there are naming conflicts
- Session attributes are included in all telemetry data (logs, events, exceptions, traces)

### Data Collection Control

Faro provides the ability to enable or disable data collection at runtime. This setting is automatically persisted across app restarts, so you don't need to set it every time your app starts.

#### Getting Current State

```dart
bool isEnabled = Faro().enableDataCollection;
```

#### Enabling/Disabling Data Collection

```dart
// Disable data collection (automatically persisted)
Faro().enableDataCollection = false;
```

#### Persistence Behavior

- **Default State**: Data collection is enabled by default on first app launch
- **Automatic Persistence**: Any changes to the data collection setting are automatically saved to device storage
- **Cross-Session**: The setting persists across app restarts, device reboots, and app updates
- **Storage**: Uses SharedPreferences on both iOS and Android for reliable persistence

#### Use Cases

This feature is particularly useful for:

- **Privacy Controls**: Allow users to opt-out of data collection
- **Compliance**: Meet regulatory requirements for data collection consent
