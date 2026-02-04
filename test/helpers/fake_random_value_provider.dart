import 'package:faro/src/util/random_value_provider.dart';

/// Fake implementation for deterministic testing.
/// Returns a fixed value on each call to [nextDouble].
class FakeRandomValueProvider implements RandomValueProvider {
  /// Creates a fake provider that always returns [fixedValue].
  FakeRandomValueProvider(this.fixedValue);

  /// The fixed value returned by [nextDouble].
  final double fixedValue;

  @override
  double nextDouble() => fixedValue;
}
