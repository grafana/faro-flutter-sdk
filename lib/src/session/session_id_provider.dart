import 'dart:math';

class SessionIdProvider {
  final sessionId = _generateSessionID();

  static String _generateSessionID() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    const length = 10;

    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }
}

class SessionIdProviderFactory {
  static SessionIdProvider? _sessionIdProvider;

  SessionIdProvider create() {
    _sessionIdProvider ??= SessionIdProvider();
    return _sessionIdProvider!;
  }
}
