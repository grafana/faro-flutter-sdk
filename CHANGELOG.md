## 0.3.0

- Restructure where faro code is located. Moved from `packages/faro` to root. Since we only have one package in this repo for now

## 0.2.2

- Enhanced Android Exit Info filtering to reduce noise in crash reports
- Improved JSON parsing and error handling in model classes
- Added comprehensive test coverage for model serialization
- Fixed handling of non-string values in exception context and stacktrace

## 0.2.0

- Renamed package from `rum_sdk` to `faro`
- Renamed main API class from `RumFlutter` to `Faro`
- Renamed all related classes with "Rum" prefix to "Faro" prefix
- Updated all import statements to use the new package name
- Updated documentation with new package name and examples

## 0.1.2

- Bug fixes and improvements

## 0.0.1

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
