import 'package:faro/src/configurations/sampling.dart';
import 'package:faro/src/models/meta.dart';
import 'package:faro/src/session/sampling_context.dart';
import 'package:faro/src/util/random_value_provider.dart';
import 'package:flutter/foundation.dart';

/// Default sampling configuration (100% of sessions).
const Sampling _defaultSampling = SamplingRate(1);

/// Determines if a session should be sampled.
///
/// The sampling decision is made once at construction time and is immutable.
/// This ensures consistent behavior throughout the session lifecycle.
class SessionSamplingProvider {
  /// Creates a sampling provider.
  ///
  /// The [sampling] configuration determines the sampling rate. If not
  /// provided, defaults to [SamplingRate(1.0)] (all sessions sampled).
  SessionSamplingProvider({
    Sampling? sampling,
    required Meta meta,
    required RandomValueProvider randomValueProvider,
  }) : isSampled = randomValueProvider.nextDouble() <
            (sampling ?? _defaultSampling).resolve(SamplingContext(meta: meta));

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
  /// The [sampling] configuration determines the sampling rate. If not
  /// provided, defaults to [SamplingRate(1.0)] (all sessions sampled).
  ///
  /// Subsequent calls return the cached instance regardless of parameters.
  ///
  /// If [randomValueProvider] is not provided, uses the default from
  /// [RandomValueProviderFactory].
  SessionSamplingProvider create({
    Sampling? sampling,
    required Meta meta,
    RandomValueProvider? randomValueProvider,
  }) {
    _instance ??= SessionSamplingProvider(
      sampling: sampling,
      meta: meta,
      randomValueProvider:
          randomValueProvider ?? RandomValueProviderFactory().create(),
    );
    return _instance!;
  }

  /// Resets the singleton instance. Primarily for testing purposes.
  @visibleForTesting
  void reset() => _instance = null;
}
