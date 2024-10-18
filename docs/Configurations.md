## Configurations

### Http Tracking
To enable tracking http requests you can override the global HttpOverrides (if you have any other overrides add them before adding RumHttpOverrides) 

```dart
  HttpOverrides.global = RumHttpOverrides(HttpOverrides.current);

```

### Mobile Vitals
Mobile Vitals such as cpu usage, memory usage & refresh rate are disabled by default. 
The interval for how often the vitals are sent  can also be 
given (default is set to 60 seconds)

```dart
  RumFlutter().runApp(
    optionsConfiguration: RumConfig(
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

The RUM logs can be batched and sent to the server in a single request. The batch size and the interval for sending the batch can be configured.

```dart
  RumFlutter().runApp(
    optionsConfiguration: RumConfig(
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

Limit the number of concurrent requests made to the RUM server 

```dart
  RumFlutter().runApp(
    optionsConfiguration: RumConfig(
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
  RumFlutter().runApp(
optionsConfiguration: RumConfig(
// ...
enableCrashReporting: false
// ...
),
appRunner:
//...

)

```


RUM Navigator Observer can be added to the list of observers to get view info and also send `view_changed` events when the route changes

```dart
    return MaterialApp(
        //...
      navigatorObservers: [RumNavigationObserver()],
      //...
      ),
```

### RUM User Interactions Widget

Add the Rum User Interactions Widget at the root level to enable the tracking of user interactions (click,tap...)

```dart
  RumFlutter().runApp(
    optionsConfiguration: RumConfig(
        //...
    ),
    appRunner: () => runApp(
       const RumUserInteractionWidget(child: MyApp())
    ),
  );
```

### RUM Asset Bundle

Add the Rum Asset Bundle to track asset load info

```dart
//..
    appRunner: () => runApp(
      DefaultAssetBundle(bundle: RumAssetBundle(), child: const RumUserInteractionWidget(child: MyApp()))
    ),
    //..
```

### Sending Custom Events



```dart
    RumFlutter().pushEvent(String name, {Map<String, String>? attributes})
    // example
    RumFlutter().pushEvent("event_name")
    RumFlutter().pushEvent("event_name", attributes:{
        attr1:"value"
    })
```


### Sending Custom Logs
```dart
RumFlutter().pushLog(String message, {String? level ,Map<String, dynamic>? context,Map<String, dynamic>? trace})
//example 
RumFlutter().pushLog("log_message",level:"warn")
```

### Sending Custom Measurements
- values can only have numeric values
```dart
    RumFlutter().pushMeasurement(Map<String, dynamic >? values, String type)
    RumFlutter().pushMeasurement({attr1:13.1, attr2:12},"some_measurements")
```

### Sending Custom Errors
```dart
    RumFlutter().pushError({required type, required value, StackTrace? stacktrace,  String? context})
```

### Capturing Event Duration

To capture the duration of an event you can use the following methods

```dart 
    RumFlutter().markEventStart(String key,String name)
    // code 
    RumFlutter().markEventEnd(String key,String name, {Map<String, String>? attributes})
```



### Adding User Meta
```dart
    RumFlutter().setUserMeta({String? userId, String? userName, String? userEmail});
    // example
    RumFlutter().addUserMeta(userId:"123",userName:"user",userEmail:"jhondoes@something.com")
```
