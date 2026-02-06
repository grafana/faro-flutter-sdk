import 'package:faro/src/session/sampling_context.dart';

/// Defines how sessions should be sampled.
///
/// Use one of the concrete implementations:
/// - [SamplingRate] for a fixed sampling rate
/// - [SamplingFunction] for dynamic sampling based on context
///
/// Example:
/// ```dart
/// // Fixed 10% sampling
/// FaroConfig(
///   sampling: SamplingRate(0.1),
/// )
///
/// // Dynamic sampling based on context
/// FaroConfig(
///   sampling: SamplingFunction((context) {
///     if (context.meta.app?.environment == 'production') {
///       return 0.1;
///     }
///     return 1.0;
///   }),
/// )
/// ```
sealed class Sampling {
  const Sampling();

  /// Resolves the sampling rate for the given context.
  ///
  /// Returns a value between 0.0 and 1.0.
  double resolve(SamplingContext context);
}

/// Fixed sampling rate.
///
/// Use this when you want a constant sampling probability regardless of
/// session context.
///
/// Example:
/// ```dart
/// FaroConfig(
///   sampling: SamplingRate(0.1), // 10% of sessions
/// )
/// ```
class SamplingRate extends Sampling {
  /// Creates a fixed sampling rate.
  ///
  /// The [rate] must be between 0.0 and 1.0:
  /// - `1.0`: Sample all sessions (100%)
  /// - `0.5`: Sample half of sessions (50%)
  /// - `0.0`: Sample no sessions (0%)
  const SamplingRate(this.rate);

  /// The fixed sampling rate (0.0 to 1.0).
  final double rate;

  @override
  double resolve(SamplingContext context) => rate.clamp(0.0, 1.0);
}

/// Dynamic sampling based on context.
///
/// Use this when you want to make sampling decisions based on session
/// metadata like user attributes, app environment, or other context.
///
/// Example:
/// ```dart
/// FaroConfig(
///   sampling: SamplingFunction((context) {
///     // Sample all beta users
///     if (context.meta.user?.attributes?['role'] == 'beta') {
///       return 1.0;
///     }
///     // Sample 10% of production sessions
///     if (context.meta.app?.environment == 'production') {
///       return 0.1;
///     }
///     return 1.0;
///   }),
/// )
/// ```
class SamplingFunction extends Sampling {
  /// Creates a dynamic sampler with the given function.
  ///
  /// The [function] receives a [SamplingContext] and should return a
  /// sampling rate between 0.0 and 1.0.
  const SamplingFunction(this.function);

  /// The sampling function that determines the rate based on context.
  final double Function(SamplingContext context) function;

  @override
  double resolve(SamplingContext context) => function(context).clamp(0.0, 1.0);
}
