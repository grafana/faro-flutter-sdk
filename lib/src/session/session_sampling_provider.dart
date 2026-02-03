import 'package:faro/src/util/random_value_provider.dart';
import 'package:flutter/foundation.dart';

/// Determines if a session should be sampled.
///
/// The sampling decision is made once at construction time and is immutable.
/// This ensures consistent behavior throughout the session lifecycle.
class SessionSamplingProvider {
  /// Creates a sampling provider with the given [samplingRate].
  ///
  /// The [samplingRate] is clamped to the valid range [0.0, 1.0] to ensure
  /// safe behavior even if an invalid value is provided in production builds
  /// (where assert statements are not checked).
  SessionSamplingProvider({
    required double samplingRate,
    required RandomValueProvider randomValueProvider,
  }) : isSampled =
            randomValueProvider.nextDouble() < samplingRate.clamp(0.0, 1.0);

  /// Whether this session is sampled.
  ///
  /// When `true`, telemetry data will be sent for this session.
  /// When `false`, telemetry data will be dropped.
  final bool isSampled;
}

/// Factory for creating [SessionSamplingProvider] instances.
///
/// Uses singleton pattern to ensure the sampling decision is made only once
/// per session and remains consistent.
class SessionSamplingProviderFactory {
  static SessionSamplingProvider? _instance;

  /// Creates or returns the singleton [SessionSamplingProvider] instance.
  ///
  /// The [samplingRate] is only used when creating the first instance.
  /// Subsequent calls return the cached instance regardless of the provided
  /// [samplingRate].
  ///
  /// If [randomValueProvider] is not provided, uses the default from
  /// [RandomValueProviderFactory].
  SessionSamplingProvider create({
    required double samplingRate,
    RandomValueProvider? randomValueProvider,
  }) {
    _instance ??= SessionSamplingProvider(
      samplingRate: samplingRate,
      randomValueProvider:
          randomValueProvider ?? RandomValueProviderFactory().create(),
    );
    return _instance!;
  }

  /// Resets the singleton instance. Primarily for testing purposes.
  @visibleForTesting
  void reset() => _instance = null;
}
