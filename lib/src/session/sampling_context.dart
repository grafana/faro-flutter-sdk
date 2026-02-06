import 'package:faro/src/models/meta.dart';

/// Context passed to sampling functions.
///
/// Provides access to the current metadata state at SDK initialization time,
/// allowing sampling decisions based on session attributes, user info, app
/// environment, and other metadata.
///
/// This aligns with the Faro Web SDK's `SamplingContext` which provides
/// `{ metas: Meta }` to the sampler function.
///
/// Example usage:
/// ```dart
/// sampler: (context) {
///   // Sample all beta users
///   if (context.meta.user?.attributes?['role'] == 'beta') {
///     return 1.0;
///   }
///   // Sample 10% of production sessions
///   if (context.meta.app?.environment == 'production') {
///     return 0.1;
///   }
///   return 1.0;
/// }
/// ```
class SamplingContext {
  /// Creates a sampling context with the given metadata.
  const SamplingContext({required this.meta});

  /// The current metadata state.
  ///
  /// Contains:
  /// - `session`: Session ID and attributes (including custom
  ///   sessionAttributes)
  /// - `user`: User info (from initialUser or persisted user)
  /// - `app`: App info (name, environment, version, namespace)
  /// - `sdk`: SDK name and version
  /// - `view`: Current view name
  final Meta meta;
}
