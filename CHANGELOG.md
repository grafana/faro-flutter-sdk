# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
