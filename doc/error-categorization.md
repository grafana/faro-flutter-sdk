# Errors, Crashes, and ANRs

This document explains how the Faro Flutter SDK captures error-like signals,
which category each one is reported as, and how to choose the right API when
you report something yourself.

It is a reference for the categories the SDK produces today. File paths are
relative to the repository root.

---

## Two signal kinds: exceptions and logs

The SDK reports error-like information as one of two distinct signal kinds,
carried in separate arrays of the Faro payload (`lib/src/models/payload.dart`):

- **Exceptions** — `Faro().pushError(...)` creates a `FaroException`
  (`lib/src/models/exception.dart`) with a `type`, `value`,
  structured `stacktrace.frames`, an optional string `context` map, and a
  `fatal` flag. It is serialized into the **`exceptions`** array.
- **Logs** — `Faro().pushLog(..., level: LogLevel.error)` creates a `FaroLog`
  (`lib/src/models/log.dart`) and is serialized into the **`logs`** array
  with `level=error`.

These stay separate end to end. A Faro backend materializes exceptions and
logs as different record kinds (for example, `kind=exception` vs `kind=log`),
and error/crash dashboards are typically built on the exception kind. So an
**error-level log is not the same as an exception** and is generally not
counted toward error or crash rates. If something represents a crash or an
unhandled error, report it through `pushError` so it lands in the
`exceptions` array; use `pushLog(level: LogLevel.error)` for diagnostic
messages that should not inflate error counts.

> The exact record kinds and field names you query depend on your Faro
> backend (for example, Grafana Cloud Frontend Observability, or a
> self-hosted collector). The two-array distinction above is part of the
> Faro payload the SDK sends and is independent of where you send it.

---

## Categories

The SDK organizes error-like signals into four categories:

1. **Crash** — the process died unexpectedly. Captured from the platform on
   the next launch and reported as a fatal exception.
2. **ANR** (Application Not Responding) — the main thread was blocked long
   enough for the platform to consider the app unresponsive.
3. **Non-fatal exception** — an error the app caught or that the framework
   surfaced, while the process kept running.
4. **Log** — a message recorded via `pushLog`, including at `error` level.
   Not a crash or an exception.

---

## How sources map to categories today

| Signal source | Where | Reported as | `type` | `fatal` |
|---------------|-------|-------------|--------|---------|
| Flutter framework errors (`FlutterError.onError`) | `lib/src/integrations/flutter_error_integration.dart` | non-fatal exception | `flutter_error` | `false` |
| Uncaught async Dart errors (`PlatformDispatcher.instance.onError`) | `lib/src/integrations/on_error_integration.dart` | non-fatal exception | `flutter_error` | `false` |
| `runZonedGuarded` errors | `lib/src/integrations/run_zoned_integration.dart` | non-fatal exception | `flutter_error` | `false` |
| Manual `Faro().pushError(...)` | `lib/src/faro.dart` | exception | caller-defined | caller-defined (default `false`) |
| Android previous-session exits via `ApplicationExitInfo` | `lib/src/faro.dart` (`enableCrashReporter`), `android/.../ExitInfoHelper.java` | fatal exception | `crash` | `true` |
| Android runtime ANR watchdog (main thread blocked) | `android/.../ANRTracker.java`, `lib/src/integrations/native_integration.dart` | exception (plus an `anr` measurement) | `flutter_error` | `true` |
| iOS previous-session crashes (PLCrashReporter) | `ios/faro/Sources/faro/CrashReportingIntegration.swift` | fatal exception | signal name (e.g. `SIGSEGV`) | `true` |
| Manual `Faro().pushLog(..., level: LogLevel.error)` | `lib/src/faro.dart` | log | — | — |

Notes:

- Automatic Dart error capture (the first three rows) is controlled by
  `enableErrorReporting`. Native crash and ANR capture is controlled by
  `enableCrashReporting` / `anrTracking`.
- Dart-level errors currently share the generic `type: 'flutter_error'`
  rather than the underlying error class.
- Native crash and ANR signals are detected from the **previous** run and
  reported on the next launch.

---

## Choosing the right API

- Report a handled error or a custom failure you want to track as an error:
  `Faro().pushError(type: ..., value: ..., stacktrace: ...)`.
- Record a diagnostic message (even at `error` level) that should not count
  as an error: `Faro().pushLog(message, level: LogLevel.error)`.
- Let the SDK capture framework, async, and zone errors for you by leaving
  `enableErrorReporting` on (the default).
