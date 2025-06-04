# Contributing to Faro Flutter SDK

Thank you for your interest in contributing to the Faro Flutter SDK! We welcome contributions from the community and are pleased to have you join us.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Release Process](#release-process)
- [Getting Help](#getting-help)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [conduct@grafana.com](mailto:conduct@grafana.com).

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable version)
- [Dart SDK](https://dart.dev/get-dart) (comes with Flutter)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extensions
- [CocoaPods](https://cocoapods.org/) (for iOS development)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/faro-flutter-sdk.git
   cd faro-flutter-sdk
   ```
3. Add the upstream repository as a remote:
   ```bash
   git remote add upstream https://github.com/grafana/faro-flutter-sdk.git
   ```

## Development Setup

1. **Install dependencies:**

   ```bash
   flutter pub get
   ```

2. **Run tests:**

   ```bash
   flutter test
   ```

3. **Set up the example app:**

   ```bash
   # Set the Faro collector URL environment variable
   export FARO_COLLECTOR_URL="your-faro-collector-url"

   # Create API configuration file (required for example app)
   bash tool/create-api-config-file.sh
   ```

   **Note**:

   - Get your `FARO_COLLECTOR_URL` from Grafana Frontend Observability if using Grafana Cloud
   - This creates `example/api-config.json` with your Faro collector URL
   - You can manually edit this file later if needed

4. **Run the example app:**

   **Option A: Using VS Code (Recommended)**

   - Open the project in VS Code
   - Use the "Run example app" launch configuration (F5)

   **Option B: Command Line**

   ```bash
   cd example
   flutter run --dart-define-from-file api-config.json
   ```

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior vs. actual behavior
- Flutter version, platform (iOS/Android), and device information
- Code samples or screenshots if applicable
- Error logs or stack traces

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:

- Check existing feature requests to avoid duplicates
- Clearly describe the enhancement and its benefits
- Provide examples of how the feature would be used
- Consider the scope and impact on existing functionality

### Contributing Code

1. **Create a branch** for your contribution:

   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b bugfix/your-bug-fix
   ```

1. **Make your changes** following our [coding standards](#coding-standards)

1. **Write tests** for your changes

1. **Update documentation** if needed

1. **Update [CHANGELOG](CHANGELOG.md)** if needed. Add your changes under the `## Unreleased` section

1. **Run the pre-release checks** (validates everything before PR):

   ```bash
   dart tool/pre_release_check.dart
   ```

1. **Commit your changes** with a clear message:

   ```bash
   git commit -m "feat: add new feature description"
   # or
   git commit -m "fix: resolve issue description"
   ```

1. **Push to your fork** and create a pull request

## Coding Standards

### Dart/Flutter Guidelines

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` for consistent formatting
- Run `dart analyze` to catch potential issues
- Use meaningful variable and function names
- Add doc comments for public APIs

### Code Organization

- Keep files focused and reasonably sized
- Group related functionality together
- Use appropriate design patterns (singleton, factory, etc.)

### Naming Conventions

- Classes: `PascalCase`
- Functions and variables: `camelCase`
- Constants: `lowerCamelCase`
- Files: `snake_case.dart`

## Testing

### Test Requirements

- Aim for writing unit tests for all business logic
- Platform-specific tests where applicable

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/src/models/trace_test.dart
```

### Test Structure

```dart
group('YourClass:', () {
  setUp(() {
    // Setup code
  });

  test('should do something when condition is met', () {
    // Arrange
    final instance = YourClass();

    // Act
    final result = instance.doSomething();

    // Assert
    expect(result, equals(expectedValue));
  });
});
```

## Documentation

### Code Documentation

- Document all public APIs
- Include examples in documentation where helpful
- Keep documentation up to date with code changes

### Project Documentation

- Update relevant documentation files for changes
- Add new documentation for new features
- Follow the existing documentation style and structure

## Release Process

Contributors don't need to worry about releases - maintainers handle this process. However, please:

- Add your changes to `CHANGELOG.md` under `## Unreleased`
- Follow semantic versioning principles when describing changes
- See [RELEASING.md](RELEASING.md) for the complete release process

## Getting Help

- **Questions?** Open a GitHub Discussion or issue

---

Thank you for contributing to Faro Flutter SDK! Your efforts help make mobile observability better for everyone.
