import 'package:faro/src/util/short_id.dart';

class SessionIdProvider {
  final sessionId = generateShortId();
}

class SessionIdProviderFactory {
  static SessionIdProvider? _sessionIdProvider;

  SessionIdProvider create() {
    _sessionIdProvider ??= SessionIdProvider();
    return _sessionIdProvider!;
  }
}
