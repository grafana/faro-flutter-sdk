import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/session/session_activity_kind.dart';

/// Decides whether a telemetry item extends the session inactivity window.
class SessionActivityPolicy {
  /// Whether telemetry classified as [kind] records session activity.
  bool recordsActivity(SessionActivityKind kind) {
    switch (kind) {
      case SessionActivityKind.meaningful:
        return true;
      case SessionActivityKind.passive:
        return false;
    }
  }
}

final sessionActivityPolicyProvider = Provider(
  (_) => SessionActivityPolicy(),
  scope: faroInitScope,
);
