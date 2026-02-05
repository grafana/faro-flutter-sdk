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
        'attr1': 'value'
    })
```

> **Note**: Faro events use string attributes (consistent with the Faro protocol). For typed attributes (int, double, bool), use distributed tracing spans instead - see [Distributed Tracing](#distributed-tracing).

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
// Basic span creation with typed attributes
final result = await Faro().startSpan('user_action', (span) async {
  // You can add more typed attributes within the callback
  span.setAttribute('item_count', 3);  // int

  return await performUserAction();
}, attributes: {
  'user_id': 123,              // int - preserved for numeric queries
  'action_type': 'purchase',   // String
  'is_premium': true,          // bool
});

// Or set all typed attributes within the callback
final result = await Faro().startSpan('user_action', (span) async {
  span.setAttributes({
    'user_id': 123,            // int
    'cart_total': 99.99,       // double
    'has_coupon': true,        // bool
    'action_type': 'purchase', // String
  });

  return await performUserAction();
});

// Nested spans - child spans automatically inherit parent context
await Faro().startSpan('checkout_process', (parentSpan) async {
  parentSpan.setAttributes({
    'cart_size': 3,            // int
    'cart_total': 149.99,      // double
  });

  await Faro().startSpan('validate_payment', (childSpan) async {
    childSpan.setAttributes({
      'payment_method': 'credit_card',
      'amount': 149.99,        // double - enables price range queries
    });
    return await validatePayment();
  });

  return await Faro().startSpan('process_order', (childSpan) async {
    childSpan.setAttributes({
      'order_priority': 1,     // int
      'is_express': true,      // bool
    });
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
    span.addEvent('Operation failed', attributes: {
      'retry_count': 3,        // int
      'should_retry': true,    // bool
    });
    rethrow;
  }
  // Span automatically ended
}, attributes: {
  'operation_id': 123,         // int
  'timeout_seconds': 30,       // int - not a string!
});
```

#### Manual Span Management

Use `startSpanManual()` when you need explicit control over span lifecycle:

```dart
// Manual span creation - requires manual status management
final span = Faro().startSpanManual('background_task',
  attributes: {
    'task_id': 123,            // int
    'priority': 'high',        // String
  });

try {
  await performTask();
  span.setStatus(SpanStatusCode.ok);  // Manual status setting required
} catch (e) {
  span.setStatus(SpanStatusCode.error, message: e.toString());  // Manual error handling required
  span.addEvent('Task failed', attributes: {
    'error': e.toString(),
    'attempt': 1,              // int
  });
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
void addContextToCurrentSpan(String key, Object value) {
  final activeSpan = Faro().getActiveSpan();
  if (activeSpan != null) {
    activeSpan.setAttribute(key, value);  // Preserves type
  }
}

// Usage
await Faro().startSpan('main_operation', (span) async {
  await doSomeWork();
  addContextToCurrentSpan('items_processed', 42);  // int attribute
  addContextToCurrentSpan('success_rate', 0.98);   // double attribute
});
```

#### Span Operations

```dart
// Add typed attributes - supports String, int, double, and bool
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
  'progress': 50,                  // int (not string!)
  'completion_rate': 0.5,          // double
  'on_track': true,                // bool
});

// Set span status (optional - startSpan() handles this automatically)
span.setStatus(SpanStatusCode.ok);  // Usually not needed
span.setStatus(SpanStatusCode.error, message: 'Something went wrong');  // Optional for custom error messages

// Record exceptions
span.recordException(exception, stackTrace: stackTrace);
```

> **Typed Attributes**: Span attributes preserve their original types (int, double, bool, String) when sent via OTLP. This enables proper numeric querying and bucketing in Grafana/Tempo - for example, you can filter traces where `account_count > 10` or create histograms of `balance` values.

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
      'cost_center': 1234,           // int - preserved for numeric queries
      'is_beta_user': true,          // bool - preserved as boolean
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
- **Type handling**: Session attributes support typed values (String, int, double, bool):
  - **Faro session** (`meta.session.attributes`): Values are stringified per Faro protocol requirements
  - **Span resources** (`resource.attributes`): Types are preserved (int, double, bool, String), enabling numeric queries and filtering in trace backends

### Session Sampling

Control what percentage of sessions send telemetry data. This is useful for managing costs and reducing traffic for high-volume applications.

#### Fixed Sampling Rate

Use `SamplingRate` for a constant sampling probability:

```dart
Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
    sampling: SamplingRate(0.5), // Sample 50% of sessions
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

**Example values:**

| Sampling            | Behavior                                       |
| ------------------- | ---------------------------------------------- |
| Not provided        | All sessions sampled (default - send all data) |
| `SamplingRate(1.0)` | All sessions sampled (100%)                    |
| `SamplingRate(0.5)` | 50% of sessions sampled                        |
| `SamplingRate(0.1)` | 10% of sessions sampled                        |
| `SamplingRate(0.0)` | No sessions sampled (no data sent)             |

#### Dynamic Sampling

Use `SamplingFunction` for dynamic sampling decisions based on session context such as user attributes, app environment, or session metadata:

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
