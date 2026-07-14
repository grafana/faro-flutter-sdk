import 'package:faro/src/session/app_lifecycle_service.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_activity_policy.dart';
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records session lifecycle notifications for assertions.
///
/// Register [onSessionChanged] via [SessionManager.addListener].
class _RecordingObserver {
  int startedCount = 0;
  String? lastCurrentId;
  String? lastPreviousId;
  SessionStartTrigger? lastTrigger;

  /// Optional hook invoked inside [onSessionChanged], used to simulate
  /// telemetry that re-enters the manager during rotation.
  void Function()? onStarted;

  void reset() {
    startedCount = 0;
    lastCurrentId = null;
    lastPreviousId = null;
    lastTrigger = null;
  }

  void onSessionChanged({
    required String currentId,
    String? previousId,
    required SessionStartTrigger trigger,
  }) {
    startedCount++;
    lastCurrentId = currentId;
    lastPreviousId = previousId;
    lastTrigger = trigger;
    onStarted?.call();
  }
}

void main() {
  group('SessionManager:', () {
    const inactivityTimeout = Duration(minutes: 15);
    const maxLifetime = Duration(hours: 4);

    late DateTime now;
    late _RecordingObserver observer;

    // Builds an inert manager wired to [observer]. Call `start()` before
    // exercising `checkSession` (see [createManager]).
    SessionManager buildManager({
      Duration inactivity = inactivityTimeout,
      Duration lifetime = maxLifetime,
      AppLifecycleService? lifecycleService,
    }) {
      final lifecycle = lifecycleService ?? AppLifecycleService();
      return SessionManager(
        sessionIdProvider: SessionIdProvider(),
        activityPolicy: SessionActivityPolicy(lifecycle),
        inactivityTimeout: inactivity,
        maxLifetime: lifetime,
        currentTimeProvider: () => now,
      )..addListener(observer.onSessionChanged);
    }

    // Builds a started (active) manager and clears the observer, so
    // subsequent `startedCount` reflects rotations only.
    SessionManager createManager({
      Duration inactivity = inactivityTimeout,
      Duration lifetime = maxLifetime,
      AppLifecycleService? lifecycleService,
    }) {
      final manager = buildManager(
        inactivity: inactivity,
        lifetime: lifetime,
        lifecycleService: lifecycleService,
      )..start();
      observer.reset();
      return manager;
    }

    setUp(() {
      now = DateTime(2026, 6, 10, 12);
      observer = _RecordingObserver();
    });

    test('does not rotate when activity is within thresholds', () {
      final manager = createManager();

      now = now.add(const Duration(minutes: 14, seconds: 59));
      manager.checkSession(activity: SessionActivityKind.active);

      expect(observer.startedCount, 0);
      expect(manager.lastActivityAt, now);
    });

    test('rotates when inactivity reaches the timeout', () {
      final manager = createManager();

      now = now.add(inactivityTimeout);
      manager.checkSession(activity: SessionActivityKind.active);

      expect(observer.startedCount, 1);
    });

    test('rotates when lifetime reaches the max, despite activity', () {
      final manager = createManager();

      // Stay active every 10 minutes; inactivity never expires.
      const step = Duration(minutes: 10);
      final deadline = now.add(maxLifetime);
      while (now.add(step).isBefore(deadline)) {
        now = now.add(step);
        manager.checkSession(activity: SessionActivityKind.active);
      }
      expect(observer.startedCount, 0);

      now = deadline;
      manager.checkSession(activity: SessionActivityKind.active);

      expect(observer.startedCount, 1);
    });

    test('resets started and lastActivity on rotation', () {
      final manager = createManager();

      now = now.add(inactivityTimeout);
      manager.checkSession(activity: SessionActivityKind.active);
      expect(observer.startedCount, 1);
      expect(manager.startedAt, now);
      expect(manager.lastActivityAt, now);

      // New session is fresh: just under the threshold does not rotate.
      now = now.add(const Duration(minutes: 14));
      manager.checkSession(activity: SessionActivityKind.active);
      expect(observer.startedCount, 1);

      // But crossing the threshold from the rotated session does.
      now = now.add(inactivityTimeout);
      manager.checkSession(activity: SessionActivityKind.active);
      expect(observer.startedCount, 2);
    });

    test('generates a new id and tracks the previous one on rotation', () {
      final manager = createManager();
      final initialId = manager.currentSessionId;
      expect(manager.previousSessionId, isNull);

      now = now.add(inactivityTimeout);
      manager.checkSession(activity: SessionActivityKind.active);

      expect(manager.currentSessionId, isNot(initialId));
      expect(manager.previousSessionId, initialId);
      expect(observer.lastCurrentId, manager.currentSessionId);
      expect(observer.lastPreviousId, initialId);
      expect(observer.lastTrigger, SessionStartTrigger.rotation);
    });

    test('start() announces the initial session with a null previous id', () {
      final manager = buildManager();

      manager.start();

      expect(observer.startedCount, 1);
      expect(observer.lastCurrentId, manager.currentSessionId);
      expect(observer.lastPreviousId, isNull);
      expect(observer.lastTrigger, SessionStartTrigger.initial);
    });

    test('is inert until start(): does not rotate before activation', () {
      final manager = buildManager();

      // Well past the inactivity timeout, but the manager is inert until
      // start(), so nothing rotates.
      now = now.add(const Duration(hours: 1));
      manager.checkSession(activity: SessionActivityKind.active);

      expect(observer.startedCount, 0);
    });

    test('records activity to keep the session alive', () {
      final manager = createManager();

      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(minutes: 10));
        manager.checkSession(activity: SessionActivityKind.active);
      }

      expect(observer.startedCount, 0);
    });

    test('ignores re-entrant calls during rotation', () {
      final manager = createManager();
      // Set the hook after start()/reset so it only fires on rotation.
      // Simulates the rotation emitting a session_extend event that
      // flows back through the ingestion path.
      observer.onStarted = () =>
          manager.checkSession(activity: SessionActivityKind.active);

      now = now.add(inactivityTimeout);
      manager.checkSession(activity: SessionActivityKind.active);

      expect(observer.startedCount, 1);
    });

    test('respects custom durations', () {
      final manager = createManager(
        inactivity: const Duration(seconds: 30),
        lifetime: const Duration(minutes: 5),
      );

      now = now.add(const Duration(seconds: 29));
      manager.checkSession(activity: SessionActivityKind.active);
      expect(observer.startedCount, 0);

      now = now.add(const Duration(seconds: 30));
      manager.checkSession(activity: SessionActivityKind.active);
      expect(observer.startedCount, 1);
    });

    test('rotates on custom max lifetime', () {
      final manager = createManager(
        inactivity: const Duration(minutes: 1),
        lifetime: const Duration(minutes: 2),
      );

      now = now.add(const Duration(seconds: 50));
      manager.checkSession(activity: SessionActivityKind.active);
      now = now.add(const Duration(seconds: 50));
      manager.checkSession(activity: SessionActivityKind.active);
      expect(observer.startedCount, 0);

      now = now.add(const Duration(seconds: 50));
      manager.checkSession(activity: SessionActivityKind.active);
      expect(observer.startedCount, 1);
    });

    group('SessionActivityKind.none:', () {
      test('does not extend the session', () {
        final manager = createManager();
        final sessionStart = now;

        // SDK lifecycle events (e.g. session_extend) never move
        // lastActivity forward.
        now = now.add(const Duration(minutes: 5));
        manager.checkSession(activity: SessionActivityKind.none);
        now = now.add(const Duration(minutes: 5));
        manager.checkSession(activity: SessionActivityKind.none);

        expect(observer.startedCount, 0);
        expect(manager.lastActivityAt, sessionStart);
      });

      test('still rotates the session once expired', () {
        final manager = createManager();

        // None-kind ingests below the threshold without extending.
        now = now.add(const Duration(minutes: 10));
        manager.checkSession(activity: SessionActivityKind.none);
        expect(observer.startedCount, 0);

        // The first ingest past the inactivity threshold rotates the
        // session even though it does not record activity.
        now = now.add(const Duration(minutes: 5));
        manager.checkSession(activity: SessionActivityKind.none);

        expect(observer.startedCount, 1);
        expect(manager.startedAt, now);
        expect(manager.lastActivityAt, now);
      });

      test('rotates repeatedly while only none-kind telemetry flows', () {
        final manager = createManager();

        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 3; j++) {
            now = now.add(const Duration(minutes: 5));
            manager.checkSession(activity: SessionActivityKind.none);
          }
        }

        expect(observer.startedCount, 3);
      });

      test('does not prevent active telemetry from extending', () {
        final manager = createManager();

        for (var i = 0; i < 10; i++) {
          now = now.add(const Duration(minutes: 7));
          manager.checkSession(activity: SessionActivityKind.none);
          now = now.add(const Duration(minutes: 7));
          manager.checkSession(activity: SessionActivityKind.active);
        }

        expect(observer.startedCount, 0);
      });

      test('still rotates on max lifetime', () {
        final manager = createManager(
          inactivity: const Duration(minutes: 1),
          lifetime: const Duration(minutes: 3),
        );

        for (var i = 0; i < 5; i++) {
          now = now.add(const Duration(seconds: 30));
          manager.checkSession(activity: SessionActivityKind.active);
        }
        expect(observer.startedCount, 0);

        now = now.add(const Duration(seconds: 30));
        manager.checkSession(activity: SessionActivityKind.none);
        expect(observer.startedCount, 1);
      });
    });

    group('SessionActivityKind.foregroundOnly:', () {
      test('extends the session while foregrounded', () {
        final lifecycle = AppLifecycleService()
          ..updateFromLifecycleState(AppLifecycleState.resumed);
        final manager = createManager(lifecycleService: lifecycle);
        final sessionStart = now;

        now = now.add(const Duration(minutes: 10));
        manager.checkSession(activity: SessionActivityKind.foregroundOnly);

        expect(observer.startedCount, 0);
        expect(manager.lastActivityAt, isNot(sessionStart));
      });

      test('does not extend the session while backgrounded', () {
        final lifecycle = AppLifecycleService()
          ..updateFromLifecycleState(AppLifecycleState.paused);
        final manager = createManager(lifecycleService: lifecycle);
        final sessionStart = now;

        now = now.add(const Duration(minutes: 10));
        manager.checkSession(activity: SessionActivityKind.foregroundOnly);

        expect(observer.startedCount, 0);
        expect(manager.lastActivityAt, sessionStart);
      });

      test('rotates once expired even when backgrounded', () {
        final lifecycle = AppLifecycleService()
          ..updateFromLifecycleState(AppLifecycleState.paused);
        final manager = createManager(lifecycleService: lifecycle);

        now = now.add(inactivityTimeout);
        manager.checkSession(activity: SessionActivityKind.foregroundOnly);

        expect(observer.startedCount, 1);
      });
    });

    test('asserts on non-positive inactivity timeout', () {
      expect(
        () => createManager(inactivity: Duration.zero),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts on non-positive max lifetime', () {
      expect(
        () => createManager(lifetime: const Duration(seconds: -1)),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
