import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:flutter/widgets.dart';

/// Tracks whether the app is currently in the foreground.
///
/// Single source of truth for the app's foreground/background state,
/// updated from `FaroWidgetsBindingObserver` and read by consumers that
/// vary behavior by foreground state (e.g. the telemetry router's
/// foreground-gated session activity).
class AppLifecycleService {
  bool _isInForeground = true;

  /// Whether the app is currently in the foreground (visible and
  /// interactive).
  ///
  /// Defaults to `true`: the SDK initializes while the app is
  /// foregrounded, before the first lifecycle callback arrives.
  bool get isInForeground => _isInForeground;

  /// Updates the foreground flag from an [AppLifecycleState].
  ///
  /// Only [AppLifecycleState.resumed] counts as foreground. `inactive`,
  /// `paused`, `hidden` and `detached` are treated as background so
  /// passive vitals stop extending the session (e.g. the screen is
  /// locked or the app is backgrounded).
  void updateFromLifecycleState(AppLifecycleState state) {
    _isInForeground = state == AppLifecycleState.resumed;
  }
}

/// Provides the shared [AppLifecycleService].
///
/// The widgets binding observer (writer) and the telemetry router
/// (reader) resolve the same instance, so the router always reads live
/// foreground state. Lives in [faroInitScope] so each `Faro.init` starts
/// from a fresh foreground instance (evicted by `Faro.resetForTesting`).
final appLifecycleServiceProvider = Provider(
  (_) => AppLifecycleService(),
  scope: faroInitScope,
);
