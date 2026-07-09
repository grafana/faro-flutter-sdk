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

  /// A rotation triggered by inactivity or maximum lifetime.
  rotation,
}

/// Called when a new session becomes active.
///
/// [trigger] identifies whether this is the initial session or a rotation.
typedef SessionChangedListener =
    void Function({
      required String currentId,
      String? previousId,
      required SessionStartTrigger trigger,
    });

/// Tracks session validity and rotates the session when it expires.
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

  /// Activates session tracking and announces the initial session.
  ///
  /// Until this runs, [checkSession] is a no-op. Calling [start] resets
  /// the timing baseline to now and notifies listeners so they can emit
  /// the initial `session_start`.
  void start() {
    final now = _currentTimeProvider();
    _startedAt = now;
    _lastActivityAt = now;
    _isActive = true;
    _notifySessionStarted(trigger: SessionStartTrigger.initial);
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
    }
  }

  /// Rotates the session and notifies listeners.
  void _rotate(DateTime now) {
    _isRotating = true;
    try {
      final previousId = _sessionIdProvider.sessionId;
      _sessionIdProvider.rotateSessionId();
      _startedAt = now;
      _lastActivityAt = now;
      _previousSessionId = previousId;
      _notifySessionStarted(trigger: SessionStartTrigger.rotation);
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
