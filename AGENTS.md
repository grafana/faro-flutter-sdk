# AGENTS.md - Grafana Faro Flutter SDK

## Project Overview

This is a **production-grade Flutter SDK** that implements the Grafana Faro protocol for mobile observability. It provides real user monitoring (RUM) for Flutter applications, capturing telemetry and correlating it with backend data for full-stack observability.

**Target Users**: Flutter developers integrating observability into production mobile applications.

### What is Grafana Faro?

Grafana Faro is an observability protocol designed by Grafana Labs for frontend and mobile application monitoring. It provides a standardized way to collect, process, and visualize application telemetry data.

### Telemetry Data Types

- **Logs**: Application logs and messages
- **Exceptions**: Error and exception data with stack traces
- **Measurements**: Performance metrics (CPU, memory, frame rates)
- **Events**: User interactions and application lifecycle events
- **Traces**: Distributed tracing with OpenTelemetry integration

### SDK Features

- Device & application info tracking
- Cold/warm start metrics and ANR detection
- Automatic Flutter error capture
- HTTP network request monitoring
- Asset loading performance
- Offline event caching
- Session tracking

### Documentation Links

- [Faro Flutter SDK on GitHub](https://github.com/grafana/faro-flutter-sdk)
- [Faro Flutter SDK on pub.dev](https://pub.dev/packages/faro)
- [Grafana Alloy faro.receiver](https://grafana.com/docs/alloy/latest/reference/components/faro/faro.receiver)
- [Grafana Frontend Observability](https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/)

---

## SDK Architecture

### Project Structure

```
lib/
├── faro.dart                 # Main public API (barrel exports)
├── src/
│   ├── faro.dart            # Core SDK implementation
│   ├── configurations/      # Config objects and policies
│   ├── device_info/         # Device and session management
│   ├── integrations/        # Framework integrations
│   ├── models/              # Data models and serialization
│   ├── transport/           # Network and batching logic
│   ├── tracing/             # OpenTelemetry integration
│   └── util/                # Shared utilities
ios/Classes/                 # iOS-specific implementation (Swift)
android/src/main/java/       # Android-specific implementation (Java)
test/                        # Unit and widget tests
example/                     # Example Flutter app
```

### Design Principles

- **Minimal Impact**: Low overhead on host applications
- **Privacy First**: Configurable data collection with user consent
- **Production Ready**: Robust error handling and edge case management
- **Backwards Compatible**: Public API changes require careful consideration
- **Clean Code**: Readable, maintainable code with clear intent
- **TDD When Applicable**: Test-driven development with a pragmatic approach — write tests first when it adds value, but don't be dogmatic

---

## Build/Test Commands

```bash
flutter test                              # Run all tests
flutter test test/path/to/test.dart       # Run single test file
flutter analyze                           # Static analysis and linting
dart format .                             # Format code
flutter pub get                           # Install dependencies
```

---

## Code Style Guidelines

- Use package imports (`package:faro/...`) not relative imports
- Prefer `final` over `var`, use `const` constructors when possible
- Single quotes for strings
- Lines max 80 characters
- Always declare return types
- Use `@visibleForTesting` for test-only public members
- Strict null safety: avoid `!` operator unless absolutely necessary
- Use meaningful names, avoid abbreviations
- Document all public classes and methods with `///`

## Error Handling

```dart
try {
  // Operation
} on SpecificException catch (error) {
  // Handle specific error
} catch (error) {
  // Handle general error
}
```

- Use specific exception types, catch specific errors first
- Implement proper cleanup in `dispose()` methods
- Never log sensitive information

## Commit Messages

Follow `.gitmessage` template: `type(scope): description`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

**Important**: Always show a draft of the commit message for approval before creating the actual commit. Never commit without explicit approval.

## Pull Requests

Use the PR template at `.github/pull_request_template.md`. The template includes:

- **Description**: Explain the "what" and "why" — keep it concise but complete
- **Related Issue(s)**: Link to issues being fixed or related
- **Type of Change**: Check the appropriate box(es)
- **Checklist**: Confirm docs, tests, and changelog are updated
- **Additional Notes**: Optional context for reviewers

**Important**: Always show a draft of the PR title and body for approval before creating the PR. Never create a PR without explicit approval.

---

## Example App Development

When developing features in `example/`, follow the architecture established in `example/lib/features/tracing/`.

### Feature Folder Structure

```
example/lib/features/<feature_name>/
├── domain/                           # Business logic layer
│   └── <feature>_service.dart        # Service class with business logic
├── models/                           # Data models
│   └── <model>.dart                  # Immutable model classes (use Equatable)
└── presentation/                     # UI layer
    ├── <feature>_page.dart           # Widget (ConsumerWidget)
    └── <feature>_page_view_model.dart # ViewModel + providers
```

### Riverpod ViewModel Pattern

Each feature's presentation layer uses this pattern:

**1. UiState Class** - Immutable state with Equatable:

```dart
class FeaturePageUiState extends Equatable {
  const FeaturePageUiState({required this.data, required this.isLoading});
  final List<SomeModel> data;
  final bool isLoading;
  FeaturePageUiState copyWith({...}) => ...;
  @override
  List<Object?> get props => [data, isLoading];
}
```

**2. Actions Interface** - Defines user actions:

```dart
abstract interface class FeaturePageActions {
  void clearData();
  Future<void> loadData();
}
```

**3. ViewModel** - Private Notifier implementing Actions:

```dart
class _FeaturePageViewModel extends Notifier<FeaturePageUiState>
    implements FeaturePageActions {
  late FeatureService _service;
  @override
  FeaturePageUiState build() {
    _service = ref.watch(featureServiceProvider);
    return const FeaturePageUiState(data: [], isLoading: false);
  }
  // Implement actions, delegate business logic to service
}
```

**4. Two Public Providers**:

```dart
final _viewModelProvider = NotifierProvider<_FeaturePageViewModel, FeaturePageUiState>(...);

// For watching state
final featurePageUiStateProvider = Provider<FeaturePageUiState>((ref) {
  return ref.watch(_viewModelProvider);
});

// For calling actions
final featurePageActionsProvider = Provider<FeaturePageActions>((ref) {
  return ref.read(_viewModelProvider.notifier);
});
```

**5. Page Widget** - ConsumerWidget using both providers:

```dart
class FeaturePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(featurePageUiStateProvider);
    final actions = ref.watch(featurePageActionsProvider);
    // Build UI using uiState, call actions for user interactions
  }
}
```

### Reference Implementation

See `example/lib/features/tracing/` for the complete pattern.
