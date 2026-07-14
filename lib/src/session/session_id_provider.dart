import 'package:dartypod/dartypod.dart';
import 'package:faro/src/util/short_id.dart';

/// Holds the current session id, regenerated on rotation.
class SessionIdProvider {
  String _sessionId = generateShortId();

  String get sessionId => _sessionId;

  String rotateSessionId() {
    return _sessionId = generateShortId();
  }
}

/// Provides the shared [SessionIdProvider] (a process-wide singleton).
final sessionIdProviderProvider = Provider((_) => SessionIdProvider());
