# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
