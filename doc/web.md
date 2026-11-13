# Flutter Web (Beta)

**Community-supported.** Web is not currently prioritized by the
maintainers. Our focus is iOS and Android. Web fixes and features mostly
depend on community contributions.

The SDK can run in Flutter web builds. Web support is in **beta**. It covers
core telemetry, several mobile features are not available, and not everything
has been tested on web yet.

## Setup

Initialize Faro the same way as on mobile, with no web-specific code:

```dart
// Safe to keep on web, but it does nothing there (see below).
HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);

// Also safe on web. Offline caching does nothing there.
Faro().transports.add(OfflineTransport());

await Faro().runApp(
  optionsConfiguration: FaroConfig(
    // ...
  ),
  appRunner: () => runApp(const MyApp()),
);
```

> **HTTP requests are not tracked on web.** Assigning `HttpOverrides.global`
> does not fail on web, but it does nothing. Browsers do not use `dart:io`'s
> `HttpClient`, so requests are not captured and **no HTTP telemetry is sent
> to Grafana**. Do not expect network requests from web builds to appear in
> your dashboards.

## What works on web

- Logs, events and custom measurements
- Manually created tracing spans (not automatic HTTP spans, see above)
- Exceptions and automatic Flutter error capture
- Session tracking, user identity, navigation, user actions and asset tracking
- App lifecycle events (`app_lifecycle_changed`), sent when Flutter reports a
  lifecycle change, for example when the browser tab is hidden or shown again

## What is not available on web yet

| Feature                                  | Behavior on web                                    |
| ---------------------------------------- | -------------------------------------------------- |
| HTTP network tracking                    | Not available. `HttpOverrides` does nothing on web and no HTTP telemetry is sent |
| `OfflineTransport`                       | Does nothing. Web has no file system to cache payloads in, so nothing is cached or replayed. Adding it is harmless |
| CPU, memory, refresh rate and ANR vitals | Not collected. The related config flags are ignored |
| Cold and warm start measurements         | Not reported. Cold start depends on native code, and a warm start on web would only cover the time to the next frame |
| Crash reporting                          | Not collected                                      |
| Session persistence across page loads    | A page reload starts a new session                 |
| Web vitals (TTFB, FCP, LCP)              | Not collected                                      |
| Browser and page metadata                | Not sent yet (`meta.browser` and `meta.page`)      |

## Device information on web

On web, `meta.device` and the `device_*` session attributes are not meaningful
and hold placeholder values such as `unknown`. `meta.os.name` is `web`.

## Collector CORS configuration

A browser enforces CORS on requests to the collector. Based on the headers the
SDK sends and reads, the collector should:

- Allow the `x-api-key`, `x-faro-session-id` and `content-type` request headers
  in `Access-Control-Allow-Headers`, and your app's origin in
  `Access-Control-Allow-Origin`.
- List `x-faro-session-status` in `Access-Control-Expose-Headers`. Without it
  the browser hides the header from the SDK, and the SDK cannot see that a
  session was invalidated.
