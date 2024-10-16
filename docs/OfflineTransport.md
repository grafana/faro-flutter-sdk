## Offline Transport

Add Offline Transport to enable caching of RUM Events when application is offline

- Add offline transport to pubspec.yaml

```yaml
offline_transport:
  git:
    url: <git_url>
    path: packages/offline_transport
    ref: main
```

- Add following snippet to enable offline transport

```dart

import 'package:offline_transport/offline_transport.dart';

RumFlutter().transports.add(
  OfflineTransport(maxCacheDuration: const Duration(days: 3), collectorUrl: "<faro_receiver_url>")
);

await RumFlutter().runApp(
  optionsConfiguration:
      //...
    appRunner: () async {
    runApp(
  //...
  )
  );
}
);
```
