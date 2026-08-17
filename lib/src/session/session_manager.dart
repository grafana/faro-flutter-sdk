import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/current_time_provider.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_activity_policy.dart';
import 'package:faro/src/session/session_id_provider.dart';

/// Why a session became active.
enum SessionStartTrigger {
  /// The first session after the SDK started (via [SessionManager.start]).
  initial,

  /// A rotation triggered by expiry or receiver invalidation.
  rotation,

  /// A rotation explicitly requested by the application.
  explicitReset,
}

/// Called when a new session becomes active.
///
/// [trigger] identifies why the session became active.
typedef SessionChangedListener =
    void Function({
      required String currentId,
      String? previousId,
      required SessionStartTrigger trigger,
    });

/// Why observable session state changed.
enum SessionStateChangeKind { sessionStarted, activity }

/// A snapshot of the active session state.
class SessionState {
  const SessionState({
    required this.currentSessionId,
    required this.previousSessionId,
    required this.startedAt,
    required this.lastActivityAt,
  });

  final String currentSessionId;
  final String? previousSessionId;
  final DateTime startedAt;
  final DateTime lastActivityAt;
}

typedef SessionStateChangedListener =
    void Function(SessionState state, SessionStateChangeKind changeKind);

/// Tracks session validity and rotates the session when it expires locally or
/// the receiver reports it as invalid.
///
/// A session expires when either:
/// - no activity has been recorded for [inactivityTimeout]
///   (Faro default: 15 minutes), or
/// - the session has been alive for [maxLifetime]
///   (Faro default: 4 hours).
///
/// Expiry is checked lazily when telemetry is ingested, not by a timer.
class SessionManager {
  SessionManager({
    required SessionIdProvider sessionIdProvider,
    required SessionActivityPolicy activityPolicy,
    this.inactivityTimeout = defaultInactivityTimeout,
    this.maxLifetime = defaultMaxLifetime,
    CurrentTimeProvider? currentTimeProvider,
  }) : assert(
         inactivityTimeout > Duration.zero,
         'inactivityTimeout must be positive',
       ),
       assert(maxLifetime > Duration.zero, 'maxLifetime must be positive'),
       _sessionIdProvider = sessionIdProvider,
       _activityPolicy = activityPolicy,
       _currentTimeProvider = currentTimeProvider ?? DateTime.now {
    final now = _currentTimeProvider();
    _startedAt = now;
    _lastActivityAt = now;
  }

  /// Default inactivity timeout before a session expires (15 minutes).
  static const Duration defaultInactivityTimeout = Duration(minutes: 15);

  /// Default maximum total session lifetime (4 hours).
  static const Duration defaultMaxLifetime = Duration(hours: 4);

  /// Inactivity period after which the session expires.
  final Duration inactivityTimeout;

  /// Maximum total lifetime of a session.
  final Duration maxLifetime;

  final SessionIdProvider _sessionIdProvider;
  final SessionActivityPolicy _activityPolicy;
  final CurrentTimeProvider _currentTimeProvider;
  final List<SessionChangedListener> _listeners = [];
  final List<SessionStateChangedListener> _stateListeners = [];

  late DateTime _startedAt;
  late DateTime _lastActivityAt;
  String? _previousSessionId;
  bool _isRotating = false;
  bool _isActive = false;

  /// When the current session started.
  DateTime get startedAt => _startedAt;

  /// When activity was last recorded for the current session.
  DateTime get lastActivityAt => _lastActivityAt;

  /// The id of the currently active session.
  String get currentSessionId => _sessionIdProvider.sessionId;

  /// The id of the session that preceded the current one, if known.
  String? get previousSessionId => _previousSessionId;

  /// Registers [listener] to be notified of session lifecycle changes.
  void addListener(SessionChangedListener listener) {
    _listeners.add(listener);
  }

  /// Registers [listener] for persistable session state changes.
  void addStateListener(SessionStateChangedListener listener) {
    _stateListeners.add(listener);
  }

  /// Activates session tracking and announces the initial session.
  ///
  /// Until this runs, [checkSession] is a no-op. Calling [start] resets
  /// the timing baseline to now and notifies listeners so they can emit
  /// the initial `session_start`.
  void start({String? previousSessionId}) {
    final now = _currentTimeProvider();
    _startedAt = now;
    _lastActivityAt = now;
    _previousSessionId = previousSessionId == currentSessionId
        ? null
        : previousSessionId;
    _isActive = true;
    _notifySessionStarted(trigger: SessionStartTrigger.initial);
    _notifyStateChanged(SessionStateChangeKind.sessionStarted);
  }

  /// Checks session validity and records activity per [activity].
  ///
  /// Call this before attributing telemetry to the session. If the
  /// session has expired, it rotates first so the triggering telemetry
  /// belongs to the new session.
  ///
  /// [activity] classifies the telemetry; the [SessionActivityPolicy]
  /// decides whether it extends the inactivity window.
  ///
  /// Re-entrant calls made while rotation runs are ignored.
  void checkSession({required SessionActivityKind activity}) {
    if (!_isActive || _isRotating) {
      return;
    }
    final now = _currentTimeProvider();
    if (_isExpired(now)) {
      _rotate(now);
    } else if (_activityPolicy.recordsActivity(activity)) {
      _lastActivityAt = now;
      _notifyStateChanged(SessionStateChangeKind.activity);
    }
  }

  /// Rotates a session that the receiver reported as invalid.
  ///
  /// [invalidSessionId] must still be the active session. This prevents
  /// duplicate or delayed responses for an older session from rotating a
  /// newer session again.
  void invalidateSession(String invalidSessionId) {
    if (!_isActive || _isRotating || invalidSessionId != currentSessionId) {
      return;
    }
    _rotate(_currentTimeProvider());
  }

  /// Starts a new session at an application-defined boundary.
  ///
  /// The new session starts immediately, links the current session, and resets
  /// both lifetime and inactivity timing. Calls made before [start] or while a
  /// rotation is already in progress are ignored.
  void resetSession() {
    if (!_isActive || _isRotating) {
      return;
    }
    _rotate(_currentTimeProvider(), trigger: SessionStartTrigger.explicitReset);
  }

  /// Rotates the session and notifies listeners.
  void _rotate(
    DateTime now, {
    SessionStartTrigger trigger = SessionStartTrigger.rotation,
  }) {
    _isRotating = true;
    try {
      final previousId = _sessionIdProvider.sessionId;
      _sessionIdProvider.rotateSessionId();
      _startedAt = now;
      _lastActivityAt = now;
      _previousSessionId = previousId;
      _notifySessionStarted(trigger: trigger);
      _notifyStateChanged(SessionStateChangeKind.sessionStarted);
    } finally {
      _isRotating = false;
    }
  }

  void _notifySessionStarted({required SessionStartTrigger trigger}) {
    final currentId = _sessionIdProvider.sessionId;
    final previousId = _previousSessionId;
    for (final listener in _listeners) {
      listener(currentId: currentId, previousId: previousId, trigger: trigger);
    }
  }

  void _notifyStateChanged(SessionStateChangeKind changeKind) {
    final state = SessionState(
      currentSessionId: currentSessionId,
      previousSessionId: previousSessionId,
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
    );
    for (final listener in _stateListeners) {
      listener(state, changeKind);
    }
  }

  bool _isExpired(DateTime now) {
    if (now.difference(_startedAt) >= maxLifetime) {
      return true;
    }
    return now.difference(_lastActivityAt) >= inactivityTimeout;
  }
}

/// Provides the [SessionManager].
///
/// Lives in [faroInitScope] so each `Faro.init` gets a fresh manager.
final sessionManagerProvider = Provider<SessionManager>(
  (pod) => SessionManager(
    sessionIdProvider: pod.resolve(sessionIdProviderProvider),
    activityPolicy: pod.resolve(sessionActivityPolicyProvider),
    currentTimeProvider: pod.resolve(currentTimeProvider),
  ),
  scope: faroInitScope,
);
