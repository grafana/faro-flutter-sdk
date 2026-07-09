import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/session/app_lifecycle_service.dart';
import 'package:faro/src/session/session_activity_kind.dart';

/// Decides whether a telemetry item extends the session inactivity
/// window, based on its [SessionActivityKind] and the current app state.
class SessionActivityPolicy {
  SessionActivityPolicy(this._appLifecycleService);

  final AppLifecycleService _appLifecycleService;

  /// Whether telemetry classified as [kind] records session activity.
  bool recordsActivity(SessionActivityKind kind) {
    switch (kind) {
      case SessionActivityKind.active:
        return true;
      case SessionActivityKind.foregroundOnly:
        return _appLifecycleService.isInForeground;
      case SessionActivityKind.none:
        return false;
    }
  }
}

final sessionActivityPolicyProvider = Provider(
  (pod) => SessionActivityPolicy(pod.resolve(appLifecycleServiceProvider)),
  scope: faroInitScope,
);
