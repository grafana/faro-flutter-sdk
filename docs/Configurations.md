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
Faro().pushLog(String message, {String? level ,Map<String, dynamic>? context,Map<String, dynamic>? trace})
//example
Faro().pushLog("log_message",level:"warn")
```

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

### Adding User Meta

```dart
    Faro().setUserMeta({String? userId, String? userName, String? userEmail});
    // example
    Faro().addUserMeta(userId:"123",userName:"user",userEmail:"jhondoes@something.com")
```
