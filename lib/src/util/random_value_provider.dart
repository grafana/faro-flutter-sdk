// ignore_for_file: use_setters_to_change_properties

import 'dart:math';

import 'package:flutter/foundation.dart';

/// Abstract interface for random value generation.
/// Allows deterministic testing by injecting fake implementations.
abstract class RandomValueProvider {
  /// Returns a random double value in the range [0.0, 1.0).
  double nextDouble();
}

/// Default implementation using dart:math Random.
class DefaultRandomValueProvider implements RandomValueProvider {
  /// Creates a new instance with its own Random generator.
  DefaultRandomValueProvider() : _random = Random();

  final Random _random;

  @override
  double nextDouble() => _random.nextDouble();
}

/// Factory for creating RandomValueProvider instances.
/// Uses singleton pattern to ensure consistent random values within a session.
class RandomValueProviderFactory {
  static RandomValueProvider? _instance;

  /// Creates or returns the singleton RandomValueProvider instance.
  RandomValueProvider create() {
    _instance ??= DefaultRandomValueProvider();
    return _instance!;
  }

  /// Resets the singleton instance. Primarily for testing purposes.
  @visibleForTesting
  void reset() => _instance = null;

  /// Sets a custom instance. Primarily for testing purposes.
  @visibleForTesting
  void setInstance(RandomValueProvider provider) => _instance = provider;
}
