# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **control Flutter error reporting**: new `enableFlutterErrorReporting` in `FaroConfig` to control Flutter error reporting (default = true)

## [0.5.0] - 2025-10-31

### Added

- **Custom session attributes**: New optional `sessionAttributes` parameter in `FaroConfig` for adding custom labels to all telemetry
  - Allows setting custom key-value pairs that are included in all telemetry data (logs, events, exceptions, traces, measurements)
  - Useful for access control labels, team/department segmentation, and environment-specific metadata
  - Custom attributes are merged with default attributes (SDK version, device info, etc.)
  - Default attributes take precedence if naming conflicts occur
  - Equivalent to `sessionTracking.session.attributes` in Faro Web SDK

## [0.4.2] - 2025-08-28

### Changed

- **Removed intl dependency**: Replaced custom date formatting with built-in `DateTime.toIso8601String()` method
  - Removed `intl` package dependency to reduce package footprint
  - Updated timestamp generation in Event, FaroLog, FaroException, and Measurement models
  - Uses standard ISO 8601 format via Dart's native `DateTime.toIso8601String()` method
  - Maintains compatibility while eliminating external dependency

## [0.4.1] - 2025-07-16

### Fixed

- **SDK name consistency across telemetry types**: Updated SDK identification to use consistent naming

  - Changed hardcoded 'rum-flutter' SDK name to use `FaroConstants.sdkName` for consistency with OpenTelemetry traces
  - Maintains backend-compatible version '1.3.5' for proper web SDK version validation
  - Added actual Faro Flutter SDK version to session attributes as 'faro_sdk_version' for tracking real SDK version

- **FaroZoneSpanManager span status preservation**: Fixed issue where manually set span statuses were overridden by automatic status setting
  - Added `statusHasBeenSet` property to `Span` interface to track when status has been manually set
  - Updated `FaroZoneSpanManager.executeWithSpan()` to respect manually set span statuses for both success and error cases
  - Prevents overriding of custom span statuses (e.g., business logic errors) when code executes without throwing exceptions
  - Maintains existing behavior for spans that haven't had their status manually set
  - Resolves issue #86: FaroZoneSpanManager overrides manually set span statuses on success

## [0.4.0] - 2025-07-02 ⚠️ BREAKING CHANGES

### Changed

- **BREAKING: Package structure refactoring to follow Flutter plugin conventions**: Reorganized the package to align with Flutter/Dart ecosystem standards and best practices

  - **Breaking Change**: Main entry point changed from `faro_sdk.dart` to `faro.dart`

    - The package now follows the standard `lib/<package_name>.dart` convention
    - Removed `lib/faro_sdk.dart` file entirely
    - `lib/faro.dart` is now the single main entry point with selective barrel exports

  - **Migration**: Update your imports to use the new main entry point

    ```dart
    // Before
    import 'package:faro/faro_sdk.dart';

    // After
    import 'package:faro/faro.dart';
    ```

  - **Architecture Improvements**:

    - Moved core `Faro` class implementation from `lib/faro.dart` to `lib/src/faro.dart`
    - `lib/faro.dart` now serves as a clean barrel export file exposing only public APIs
    - All implementation details properly organized under `lib/src/` directory
    - Clear separation between public API surface and private implementation
    - Follows established Flutter ecosystem conventions used by popular packages like Provider, BLoC, and Dio

  - **Benefits**:

    - **Cleaner API boundaries**: Clear distinction between public and private APIs
    - **Better maintainability**: Implementation details can evolve without affecting public interface
    - **Consistent developer experience**: Matches patterns developers expect from other Flutter packages
    - **Future-proof**: Enables easier API evolution and versioning
    - **Community alignment**: Follows official Flutter/Dart documentation recommendations

  - **No functionality changes**: All existing public APIs remain the same, only import paths have changed

### Added

- **Type-Safe Log Level API**: New `LogLevel` enum for improved logging reliability and developer experience

  - Introduced `LogLevel` enum with values: `trace`, `debug`, `info`, `log`, `warn`, `error`
  - Aligns with Grafana Faro Web SDK for cross-platform consistency
  - Includes `fromString()` method for backward compatibility, supporting both `'warn'` and `'warning'` variants

- **Enhanced Tracing and Span API**: Major improvements to distributed tracing capabilities

  - New `startSpan<T>()` method for automatic span lifecycle management with callback-based execution
  - New `startSpanManual()` method for manual span lifecycle management when precise control is needed
  - New `getActiveSpan()` method to access the currently active span from anywhere in the execution context
  - Zone-based span context management ensures proper parent-child relationships across async boundaries
  - Automatic session ID injection - all spans now include both `session_id` and `session.id` attributes
  - Improved error handling with automatic span status updates when exceptions occur
  - Enhanced span status tracking with proper OpenTelemetry status code mapping
  - Support for custom parent span specification to create explicit span hierarchies
  - Comprehensive documentation with detailed examples for common tracing patterns

- **Centralized Session Management**: New `SessionIdProvider` for consistent session handling across the SDK

  - Dedicated session ID generation and management
  - Better integration with tracing system for session context propagation
  - Factory pattern for testable session management

- **SDK Constants Management**: New centralized constants system

  - Added `FaroConstants` class for SDK version and name management
  - Better version tracking and consistency across the codebase

- **BREAKING: Synchronous API for telemetry methods**: Refactored telemetry methods to remove unnecessary async patterns for improved performance and developer experience

  - **Breaking Change**: The following methods changed from `Future<void>?` to `void`:
    - `pushEvent()` - Send custom events
    - `pushLog()` - Send custom logs
    - `pushError()` - Send custom errors
    - `pushMeasurement()` - Send custom measurements
    - `markEventEnd()` - Mark event completion
  - **Migration**: Remove `await` keywords from calls to these methods as they are now synchronous

    ```dart
    // Before
    await Faro().pushEvent('event_name');
    await Faro().pushLog('message', level: LogLevel.info);

    // After
    Faro().pushEvent('event_name');
    Faro().pushLog('message', level: LogLevel.info);
    ```

  - **Benefits**:
    - Improved performance by eliminating unnecessary async overhead
    - Cleaner API that better reflects the synchronous nature of these operations
    - Reduced complexity in application code
  - **Internal Architecture**: Introduced `BatchTransportFactory` singleton pattern for better dependency management and testing

- **BREAKING: pushLog API requires LogLevel enum**: Enhanced logging API for better type safety and consistency

  - **Breaking Change**: `pushLog()` now requires a `LogLevel` parameter instead of optional `String?`
  - **Migration**: Replace `level: "warn"` with `level: LogLevel.warn` in your pushLog calls
  - **Benefit**: Eliminates typos in log levels and provides better IDE support
  - **Compatibility**: Existing string-based log levels in internal code updated to use LogLevel enum
  - **Documentation**: All examples and documentation updated to reflect the new API

- **Tracing Architecture Refactoring**: Complete redesign of the internal tracing system

  - Replaced legacy `tracer.dart` and `tracer_provider.dart` with new `FaroTracer` implementation
  - New `FaroZoneSpanManager` for robust zone-based span context management
  - Improved `Span` class with cleaner API and better OpenTelemetry integration
  - Enhanced span creation and management with proper resource attribution
  - Better separation of concerns between tracing components
  - Zone-based implementation ensures proper parent-child relationships across async boundaries
  - Enhanced developer experience with multiple tracing approaches for different use cases
  - Better integration between tracing and other SDK components

- **Session Management**: Extracted session logic from distributed components
  - Removed deprecated `generate_session.dart` utility
  - Centralized session management in dedicated provider
  - Improved testability and maintainability of session-related functionality

## [0.3.7] - 2025-06-10

### Added

- **Enhanced HTTP tracing attributes**: HTTP spans now include additional attributes for better observability
  - Added `http.request_size` attribute with request content length
  - Added `http.response_size` attribute with response content length
  - Added `http.content_type` attribute with response content type
  - Provides more comprehensive HTTP request/response metadata for monitoring
- **Session attributes in OpenTelemetry traces**: Tracer resources now automatically include session attributes
  - Session metadata is propagated to all OpenTelemetry spans
  - Enables correlation of traces with user sessions and custom session data
  - Supports dynamic session attribute values (strings, numbers, booleans, objects)
  - Added comprehensive test coverage for `DartOtelTracerResourcesFactory`
- **Human-readable timestamps for Android crashes**: Added readable timestamp formatting for crash reports
  - Crash context now includes both original Unix epoch timestamp and human-readable ISO 8601 format
  - Added `timestamp_readable_utc` field alongside existing `timestamp` field
  - Timestamps converted to UTC ISO 8601 format (e.g., "2025-06-04T23:49:20.296Z")
  - Includes new `TimestampExtension` utility for reusable timestamp conversion
  - Improves debugging experience with easily interpretable crash timestamps
  - Resolves issue #53: Add human readable timestamp for Android crashes
- **Trace event duration**: Added duration information to trace events
  - Events now include `duration_ns` attribute with span duration in nanoseconds
  - Duration calculated as `endTime - startTime` when both timestamps are valid
  - Improves observability by providing timing information for traced operations
  - Resolves issue #23: Add duration to Faro events

### Fixed

- **Span event naming**: Fixed incorrect event names for tracing spans
  - HTTP spans now correctly use `faro.tracing.fetch` event name
  - Non-HTTP spans use `span.{name}` format for better event categorization
  - Added logic to detect HTTP spans based on `http.scheme` or `http.method` attributes
  - Resolves issue #41: Incorrect span event names being sent to collector
- **Event data URL formatting**: Fixed inconsistent formatting of event_data_url parameter
  - Attribute values are now properly sanitized to remove surrounding quotes
  - Ensures consistent formatting across all event attributes
  - Resolves issue #25: Inconsistent event_data_url formatting

## [0.3.6] - 2025-06-05

### Added

- **Data Collection Persistence**: The `enableDataCollection` setting now persists across app restarts
  - Automatically saves the data collection preference to device storage using SharedPreferences
  - Defaults to enabled on first app launch
  - Fire-and-forget persistence - no need to await setting changes
  - Maintains full backward compatibility with existing API
  - Resolves issue #62: "Persist faro.enableDataCollection"
- GitHub issue templates for bug reports and feature requests
- Pull request template for standardized contributions
- Code of Conduct (Contributor Covenant v1.4)
- Comprehensive Contributing Guidelines with setup instructions and development workflow
- Maintainers documentation listing current project maintainers

### Changed

- Major documentation overhaul:
  - Enhanced README with improved badges, clearer setup instructions, and better project description
  - Completely rewritten Features documentation with detailed explanations and code examples
  - Improved Getting Started guide with step-by-step setup for both Grafana Cloud and self-hosted options
- Updated example app to demonstrate latest SDK features and best practices

### Improved

- Project governance and community guidelines establishment
- Developer experience with better onboarding documentation
- Code contribution workflow with standardized templates and processes

### Fixed

- **Critical NullPointerException in Android frame monitoring**: Fixed crash when frame monitoring callbacks execute after Flutter engine detachment
  - Added proper cleanup in `stopFrameMonitoring()` to remove Choreographer callbacks
  - Added null checks in `handleFrameDrop()`, `handleSlowFrameDrop()`, and `handleRefreshRate()` methods
  - Added safety guards to prevent frame processing when monitoring is stopped
  - Prevents crashes when app goes to background or during configuration changes

## [0.3.5] - 2025-05-28

### Added

- Support for custom HTTP headers in `FaroConfig` via the `collectorHeaders` field
  - Allows users to specify headers that will be included in all requests to the collector endpoint
  - Useful for deployments that require specific headers for routing or authentication

## [0.3.4] - 2025-05-22

### Added

- Automated pub.dev deployment with GitHub Actions
- Pre-release validation tools

### Changed

- Improved release workflow with safety checks

## [0.3.3]

### Changed

- Updated intl dependency to newer version to be compatible with latest flutter version

## [0.3.2]

### Changed

- Maintenance release

## [0.3.1]

### Changed

- Updates README

## [0.3.0]

### Changed

- Restructure where faro code is located. Moved from `packages/faro` to root. Since we only have one package in this repo for now

## [0.2.2]

### Added

- Comprehensive test coverage for model serialization

### Changed

- Enhanced Android Exit Info filtering to reduce noise in crash reports
- Improved JSON parsing and error handling in model classes

### Fixed

- Fixed handling of non-string values in exception context and stacktrace

## [0.2.0]

### Changed

- Renamed package from `rum_sdk` to `faro`
- Renamed main API class from `RumFlutter` to `Faro`
- Renamed all related classes with "Rum" prefix to "Faro" prefix
- Updated all import statements to use the new package name
- Updated documentation with new package name and examples

## [0.1.2]

### Fixed

- Bug fixes and improvements

## [0.0.1]

### Added

The following Key Metrics of Flutter Applications are Added in the Alpha Release.

- Mobile App Performance
  - cpu usage
  - memory usage
  - cold/warm start
  - ANR ( android)
  - Native slow/frozen frames
- Flutter Errors & Exceptions
- Events
  - session start
  - route changes
  - user interaction
- Http network info
  - Load Duration , method , resource/type , request/response size
- Rum Asset Bundle
  - Asset Size, Load time
- Custom events, logs, measurement, error
- Offline Caching of Events
