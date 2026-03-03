import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_actions_demo_service.dart';
import '../models/action_log_entry.dart';
import 'auto_pop_page.dart';

// =============================================================================
// UI State
// =============================================================================

/// Immutable UI state for the User Actions demo page.
class UserActionsPageUiState extends Equatable {
  const UserActionsPageUiState({
    required this.log,
    required this.isRunning,
  });

  final List<ActionLogEntry> log;
  final bool isRunning;

  UserActionsPageUiState copyWith({
    List<ActionLogEntry>? log,
    bool? isRunning,
  }) {
    return UserActionsPageUiState(
      log: log ?? this.log,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  List<Object?> get props => [log, isRunning];
}

// =============================================================================
// Actions Interface
// =============================================================================

/// User-facing actions on the User Actions demo page.
abstract interface class UserActionsPageActions {
  void clearLog();

  /// Scenario 1 - start an action with no follow-up (-> cancelled).
  Future<void> runIdleCancelScenario();

  /// Scenario 2 - start an action then fast view transitions (-> ended).
  Future<void> runFastNavigationScenario(NavigatorState navigator);

  /// Scenario 3 - start an action then one HTTP request
  /// (-> halted -> ended).
  Future<void> runSingleHttpScenario();

  /// Scenario 4 - start an action then multiple HTTP requests
  /// (-> halted -> ended when all finish).
  Future<void> runParallelHttpScenario();

  /// Scenario 5 - mixed pre/post-halt signals and fast view transitions.
  Future<void> runMixedTimingScenario(NavigatorState navigator);

  /// Scenario 6 - verify that concurrent start is rejected.
  Future<void> runConcurrentStartScenario(NavigatorState navigator);
}

// =============================================================================
// ViewModel
// =============================================================================

class _UserActionsPageViewModel extends Notifier<UserActionsPageUiState>
    implements UserActionsPageActions {
  late UserActionsDemoService _service;

  @override
  UserActionsPageUiState build() {
    _service = ref.watch(userActionsDemoServiceProvider);
    return const UserActionsPageUiState(
      log: [],
      isRunning: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _addLog(
    String message, {
    bool isError = false,
    bool isHighlight = false,
  }) {
    state = state.copyWith(
      log: [
        ...state.log,
        ActionLogEntry(
          message: message,
          timestamp: DateTime.now(),
          isError: isError,
          isHighlight: isHighlight,
        ),
      ],
    );
  }

  void _noop() {}

  Future<void> _run(
    Future<void> Function(
      LogCallback log,
      StatePollCallback onTick,
    ) operation,
  ) async {
    state = state.copyWith(isRunning: true);
    try {
      await operation(_addLog, _noop);
    } finally {
      state = state.copyWith(isRunning: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  @override
  void clearLog() {
    state = state.copyWith(log: const []);
  }

  @override
  Future<void> runIdleCancelScenario() async {
    await _run(_service.runIdleCancelScenario);
  }

  @override
  Future<void> runFastNavigationScenario(NavigatorState navigator) async {
    state = state.copyWith(isRunning: true);
    try {
      await _service.runFastNavigationScenario(
        _addLog,
        _noop,
        navigator: navigator,
        route: MaterialPageRoute(
          settings: const RouteSettings(name: '/ua-fast-nav'),
          builder: (_) => const AutoPopPage(
            title: 'Fast View Transition',
            description: 'Generating push/pop view signals.',
            autoPopDelay: Duration(milliseconds: 40),
          ),
        ),
      );
    } finally {
      state = state.copyWith(isRunning: false);
    }
  }

  @override
  Future<void> runSingleHttpScenario() async {
    await _run(_service.runSingleHttpScenario);
  }

  @override
  Future<void> runParallelHttpScenario() async {
    await _run(_service.runParallelHttpScenario);
  }

  @override
  Future<void> runMixedTimingScenario(NavigatorState navigator) async {
    state = state.copyWith(isRunning: true);
    try {
      await _service.runMixedTimingScenario(
        _addLog,
        _noop,
        navigator: navigator,
        route: MaterialPageRoute(
          settings: const RouteSettings(name: '/ua-mixed-nav'),
          builder: (_) => const AutoPopPage(
            title: 'Mixed Timing Navigation',
            description: 'Fast view change while HTTP is in-flight.',
            autoPopDelay: Duration(milliseconds: 60),
          ),
        ),
      );
    } finally {
      state = state.copyWith(isRunning: false);
    }
  }

  @override
  Future<void> runConcurrentStartScenario(NavigatorState navigator) async {
    state = state.copyWith(isRunning: true);
    try {
      await _service.runConcurrentStartScenario(
        _addLog,
        _noop,
        navigator: navigator,
        routeFactory: () {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/ua-concurrent-nav'),
            builder: (_) => const AutoPopPage(
              title: 'Concurrent Guard Navigation',
              description: 'Small view pulse to mark activity.',
              autoPopDelay: Duration(milliseconds: 40),
            ),
          );
        },
      );
    } finally {
      state = state.copyWith(isRunning: false);
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

final _viewModelProvider =
    NotifierProvider<_UserActionsPageViewModel, UserActionsPageUiState>(
  _UserActionsPageViewModel.new,
);

/// Watch this to rebuild when UI state changes.
final userActionsPageUiStateProvider = Provider<UserActionsPageUiState>((ref) {
  return ref.watch(_viewModelProvider);
});

/// Use this to call page actions.
final userActionsPageActionsProvider = Provider<UserActionsPageActions>((ref) {
  return ref.read(_viewModelProvider.notifier);
});
