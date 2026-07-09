import 'package:dartypod/dartypod.dart';

/// Global dependency container for the SDK.
final pod = Pod();

/// Scope for singletons whose lifetime is tied to a single `Faro.init`.
///
/// Providers in this scope are rebuilt on each initialization:
/// `Faro.resetForTesting` clears the scope with
/// `pod.clearScope(faroInitScope)`, so the next `init` resolves fresh
/// instances instead of leaking state across runs.
const faroInitScope = CustomScope('faroInit');
