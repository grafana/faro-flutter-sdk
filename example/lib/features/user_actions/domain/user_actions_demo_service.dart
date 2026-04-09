import 'dart:async';

import 'package:faro/faro.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Callback for logging messages to the UI.
typedef LogCallback = void Function(
  String message, {
  bool isError,
  bool isHighlight,
});

/// Callback invoked on each state-poll tick so the view model can capture
/// intermediate state changes.
typedef StatePollCallback = void Function();

/// Service that runs User Action scenarios for the example app.
///
/// Each scenario starts a user action and then exercises a different
/// follow-up pattern so you can observe the lifecycle transitions
/// (started → halted → ended, or started → cancelled).
class UserActionsDemoService {
  const UserActionsDemoService();

  // ---------------------------------------------------------------------------
  // Scenario 1 - No follow-up activity (started -> cancelled)
  // ---------------------------------------------------------------------------

  /// Starts a user action and does **nothing** afterwards.
  ///
  /// Because there is no follow-up activity the action should time out
  /// after the default follow-up timeout and transition to [UserActionState.cancelled].
  Future<void> runIdleCancelScenario(
    LogCallback log,
    StatePollCallback onTick,
  ) async {
    final run = _startScenario(
      log,
      actionName: 'ua-idle-cancel',
      scenario: 'idle_cancel',
    );
    if (run == null) {
      return;
    }

    log('No activity will be emitted. Expected: started -> cancelled.');
    onTick();

    await _pollUntilTerminal(run.action, log, onTick);

    log(
      'Final state: ${run.action.getState().name}',
      isHighlight: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Scenario 2 - Fast view transitions (started -> ended)
  // ---------------------------------------------------------------------------

  /// Starts a user action, then pushes [route] which the
  /// [FaroNavigationObserver] reports as activity.
  ///
  /// This scenario uses a route that auto-pops quickly so both push and pop
  /// happen inside the follow-up window.
  Future<void> runFastNavigationScenario(
    LogCallback log,
    StatePollCallback onTick, {
    required NavigatorState navigator,
    required Route<void> route,
  }) async {
    final run = _startScenario(
      log,
      actionName: 'ua-fast-navigation',
      scenario: 'fast_navigation',
    );
    if (run == null) {
      return;
    }

    log(
      'Triggering fast route push/pop. '
      'Expected: started -> ended.',
    );
    onTick();

    Faro().pushEvent(
      'ua.fast_navigation.marker',
      attributes: {'runId': run.runId},
    );

    log('Pushing temporary route (fast auto-pop).');
    navigator.push<void>(route);
    onTick();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _pollUntilTerminal(run.action, log, onTick);

    log(
      'Final state: ${run.action.getState().name}',
      isHighlight: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Scenario 3 - Single HTTP request (started -> halted -> ended)
  // ---------------------------------------------------------------------------

  /// Starts a user action and fires an HTTP request to a public endpoint
  /// with a built-in 3-second delay.
  ///
  /// The action should transition to [UserActionState.halted] while the
  /// request is in-flight and then to [UserActionState.ended] once it
  /// completes.
  Future<void> runSingleHttpScenario(
    LogCallback log,
    StatePollCallback onTick,
  ) async {
    final run = _startScenario(
      log,
      actionName: 'ua-http-single',
      scenario: 'single_http',
    );
    if (run == null) {
      return;
    }

    log('Expected: started -> halted -> ended.');
    onTick();

    await _runHttpGet(
      log: log,
      label: 'single-http',
      url: 'https://httpbin.io/delay/3',
    );
    onTick();

    await _pollUntilTerminal(run.action, log, onTick);

    log('Final state: ${run.action.getState().name}', isHighlight: true);
  }

  // ---------------------------------------------------------------------------
  // Scenario 4 - Parallel HTTP requests (halts until all are done)
  // ---------------------------------------------------------------------------

  /// Starts one action and fires four parallel HTTP requests.
  ///
  /// This verifies that multiple in-flight operations keep the action halted
  /// until every tracked request completes.
  ///
  /// The entire flow is wrapped in a custom parent span so it is easy to
  /// verify that non-HTTP custom spans are also correlated with the active
  /// user action.
  ///
  /// It also creates one intentionally late custom span after the action has
  /// entered `halted`, which should not get user-action context.
  Future<void> runParallelHttpScenario(
    LogCallback log,
    StatePollCallback onTick,
  ) async {
    final run = _startScenario(
      log,
      actionName: 'ua-http-parallel',
      scenario: 'parallel_http',
    );
    if (run == null) {
      return;
    }

    log(
      'Starting 4 parallel requests. '
      'Expected: halted until all requests complete.',
    );
    onTick();

    await Faro().startSpan<void>(
      'ua.parallel_http.parent_span',
      (parentSpan) async {
        log(
          'Started custom parent span '
          '(traceId=${parentSpan.traceId}, spanId=${parentSpan.spanId})',
        );
        parentSpan.addEvent('parallel_http.requests.started', attributes: {
          'runId': run.runId,
          'requestCount': 4,
        });

        final requestFutures = <Future<void>>[
          _runHttpGet(
            log: log,
            label: 'parallel-1s',
            url: 'https://httpbin.io/delay/1',
          ),
          _runHttpGet(
            log: log,
            label: 'parallel-2s',
            url: 'https://httpbin.io/delay/2',
          ),
          _runHttpGet(
            log: log,
            label: 'parallel-3s',
            url: 'https://httpbin.io/delay/3',
          ),
          _runHttpGet(
            log: log,
            label: 'parallel-6s',
            url: 'https://httpbin.io/delay/6',
          ),
        ];

        // Wait until the action should have moved to halted (or timeout).
        final reachedHalted = await _waitForState(
          run.action,
          UserActionState.halted,
          maxWait: const Duration(seconds: 2),
        );
        final stateAtLateSpan = run.action.getState();
        if (!reachedHalted) {
          log(
            'Warning: action did not reach halted before late span. '
            'Observed state=${stateAtLateSpan.name}',
            isError: true,
          );
        }

        await Faro().startSpan<void>(
          'ua.parallel_http.late_span',
          (lateSpan) {
            lateSpan.addEvent('parallel_http.late_span.created', attributes: {
              'runId': run.runId,
              'actionStateAtCreation': stateAtLateSpan.name,
            });
            log(
              'Created late span (spanId=${lateSpan.spanId}) while '
              'action state=${stateAtLateSpan.name}.',
            );
          },
          attributes: {
            'scenario': 'parallel_http_late_span',
            'runId': run.runId,
            'actionStateAtCreation': stateAtLateSpan.name,
          },
        );

        await Future.wait(requestFutures);

        parentSpan.addEvent('parallel_http.requests.completed', attributes: {
          'runId': run.runId,
        });
      },
      attributes: {
        'scenario': 'parallel_http',
        'runId': run.runId,
      },
    );
    onTick();

    await _pollUntilTerminal(run.action, log, onTick);

    log('Final state: ${run.action.getState().name}', isHighlight: true);
  }

  // ---------------------------------------------------------------------------
  // Scenario 5 - Mixed timing window (pre-halt vs post-halt signals)
  // ---------------------------------------------------------------------------

  /// Starts an action, emits early telemetry, starts HTTP, emits late
  /// telemetry after halt, and performs a fast route push/pop.
  ///
  /// This scenario is useful for manual correlation checks in Grafana:
  /// - `ua.pre_halt.*` signals are emitted while action is in `started`.
  /// - `ua.post_halt.*` signals are emitted after ~250 ms, typically
  ///   when action is already `halted`.
  Future<void> runMixedTimingScenario(
    LogCallback log,
    StatePollCallback onTick, {
    required NavigatorState navigator,
    required Route<void> route,
  }) async {
    final run = _startScenario(
      log,
      actionName: 'ua-mixed-timing',
      scenario: 'mixed_timing_window',
    );
    if (run == null) {
      return;
    }

    log(
      'Emitting pre-halt telemetry + fast navigation + long HTTP request.',
    );
    onTick();

    Faro().pushEvent(
      'ua.pre_halt.event',
      attributes: {'runId': run.runId},
    );
    Faro().pushLog(
      'ua.pre_halt.log',
      level: LogLevel.debug,
      context: {'runId': run.runId},
    );
    Faro().pushError(
      type: 'UserActionWindowScenario',
      value: 'ua.pre_halt.error',
      context: {'runId': run.runId},
    );

    navigator.push<void>(route);

    final requestFuture = _runHttpGet(
      log: log,
      label: 'mixed-window-hold',
      url: 'https://httpbin.io/delay/3',
    );
    onTick();

    await Future<void>.delayed(const Duration(milliseconds: 250));
    Faro().pushEvent(
      'ua.post_halt.event',
      attributes: {'runId': run.runId},
    );
    Faro().pushLog(
      'ua.post_halt.log',
      level: LogLevel.warn,
      context: {'runId': run.runId},
    );
    Faro().pushError(
      type: 'UserActionWindowScenario',
      value: 'ua.post_halt.error',
      context: {'runId': run.runId},
    );
    log('Emitted ua.post_halt.* (event/log/error) after 250ms.');
    onTick();

    await requestFuture;
    await _pollUntilTerminal(run.action, log, onTick);

    log(
      'Final state: ${run.action.getState().name}',
      isHighlight: true,
    );
    log(
      'Grafana hint: query runId=${run.runId} and compare '
      'ua.pre_halt.* vs ua.post_halt.* action linkage.',
      isHighlight: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Scenario 6 - Concurrent start guard (second start should fail)
  // ---------------------------------------------------------------------------

  /// Starts one action and immediately attempts to start a second action.
  ///
  /// Expected behavior:
  /// - While the first action is active, starting another action returns `null`.
  /// - After the first action terminates, starting a new action works again.
  ///
  /// This scenario uses small navigation pulses so each successful action
  /// receives activity and ends (instead of auto-cancelling).
  Future<void> runConcurrentStartScenario(
    LogCallback log,
    StatePollCallback onTick, {
    required NavigatorState navigator,
    required Route<void> Function() routeFactory,
  }) async {
    final run = _startScenario(
      log,
      actionName: 'ua-concurrent-primary',
      scenario: 'concurrent_start_guard',
    );
    if (run == null) {
      return;
    }

    log('Trying to start a second action while first is active...');
    final secondWhileActive = Faro().startUserAction(
      'ua-concurrent-secondary',
      attributes: {
        'scenario': 'concurrent_start_guard',
        'runId': run.runId,
        'source': 'example_app',
      },
    );

    if (secondWhileActive == null) {
      log(
        'Second start returned null as expected '
        '(single active action guard).',
        isHighlight: true,
      );
    } else {
      log(
        'Unexpected: second action started while first is active '
        '(id=${secondWhileActive.id}).',
        isError: true,
      );
    }
    onTick();

    Faro().pushEvent(
      'ua.concurrent.primary.event',
      attributes: {'runId': run.runId},
    );
    Faro().pushEvent(
      'ua.concurrent.primary.activity',
      attributes: {'runId': run.runId},
    );
    await _triggerNavigationPulse(
      log,
      onTick,
      navigator: navigator,
      routeFactory: routeFactory,
      phase: 'primary',
    );
    log(
      'Pushed event + navigation activity for primary action '
      'so it should end.',
    );

    await _pollUntilTerminal(run.action, log, onTick);
    log('Primary final state: ${run.action.getState().name}',
        isHighlight: true);

    final startAfterTermination = Faro().startUserAction(
      'ua-concurrent-after-release',
      attributes: {
        'scenario': 'concurrent_start_guard',
        'runId': run.runId,
        'source': 'example_app',
      },
    );

    if (startAfterTermination == null) {
      log(
        'Unexpected: could not start action after primary terminated.',
        isError: true,
      );
      return;
    }

    log(
      'After-release start succeeded '
      '(id=${startAfterTermination.id}).',
      isHighlight: true,
    );

    Faro().pushEvent(
      'ua.concurrent.after_release.event',
      attributes: {'runId': run.runId},
    );
    Faro().pushEvent(
      'ua.concurrent.after_release.activity',
      attributes: {'runId': run.runId},
    );
    await _triggerNavigationPulse(
      log,
      onTick,
      navigator: navigator,
      routeFactory: routeFactory,
      phase: 'after-release',
    );
    await _pollUntilTerminal(startAfterTermination, log, onTick);
    log(
      'After-release final state: ${startAfterTermination.getState().name}',
      isHighlight: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  _ScenarioRun? _startScenario(
    LogCallback log, {
    required String actionName,
    required String scenario,
    StartUserActionOptions? options,
  }) {
    final runId = DateTime.now().millisecondsSinceEpoch.toString();

    final action = Faro().startUserAction(
      actionName,
      attributes: {
        'scenario': scenario,
        'runId': runId,
        'source': 'example_app',
      },
      options: options,
    );

    if (action == null) {
      log('Could not start. Another user action is already active.',
          isError: true);
      return null;
    }

    log(
      'Started "${action.name}" '
      '(id=${action.id}, runId=$runId).',
      isHighlight: true,
    );

    return _ScenarioRun(action: action, runId: runId);
  }

  Future<void> _runHttpGet({
    required LogCallback log,
    required String label,
    required String url,
  }) async {
    final startedAt = DateTime.now();
    log('HTTP start [$label] -> $url');

    try {
      final response = await http.get(Uri.parse(url));
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      log('HTTP end [$label] -> ${response.statusCode} (${elapsedMs}ms)');
    } catch (error) {
      log('HTTP error [$label] -> $error', isError: true);
    }
  }

  Future<bool> _waitForState(
    UserActionHandle action,
    UserActionState expectedState, {
    Duration maxWait = const Duration(seconds: 2),
  }) async {
    const pollInterval = Duration(milliseconds: 25);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      if (action.getState() == expectedState) {
        return true;
      }
      await Future<void>.delayed(pollInterval);
    }

    return action.getState() == expectedState;
  }

  Future<void> _triggerNavigationPulse(
    LogCallback log,
    StatePollCallback onTick, {
    required NavigatorState navigator,
    required Route<void> Function() routeFactory,
    required String phase,
  }) async {
    log('Triggering short navigation pulse for $phase action...');
    navigator.push<void>(routeFactory());
    onTick();

    // Allow push+pop and follow-up debounce to settle.
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  /// Polls the action state every 200 ms until it reaches a terminal state
  /// ([UserActionState.ended] or [UserActionState.cancelled]), or until
  /// a safety limit of 15 seconds is reached.
  Future<void> _pollUntilTerminal(
    UserActionHandle action,
    LogCallback log,
    StatePollCallback onTick,
  ) async {
    const pollInterval = Duration(milliseconds: 200);
    const maxWait = Duration(seconds: 15);
    final deadline = DateTime.now().add(maxWait);
    var lastState = action.getState();

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final current = action.getState();

      if (current != lastState) {
        log(
          'State changed: ${lastState.name} → ${current.name}',
          isHighlight: true,
        );
        lastState = current;
        onTick();
      }

      if (current == UserActionState.ended ||
          current == UserActionState.cancelled) {
        return;
      }
    }

    log('Polling timed out after ${maxWait.inSeconds} s', isError: true);
  }
}

class _ScenarioRun {
  const _ScenarioRun({
    required this.action,
    required this.runId,
  });

  final UserActionHandle action;
  final String runId;
}

// =============================================================================
// Provider
// =============================================================================

final userActionsDemoServiceProvider = Provider<UserActionsDemoService>((ref) {
  return const UserActionsDemoService();
});
