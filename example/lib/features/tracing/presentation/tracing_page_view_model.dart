import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tracing_service.dart';
import '../models/span_log_entry.dart';

// =============================================================================
// UI State
// =============================================================================

/// Immutable UI state for the tracing page.
///
/// Contains all data needed to render the tracing page UI.
class TracingPageUiState extends Equatable {
  const TracingPageUiState({
    required this.spanLog,
    required this.isRunning,
  });

  /// Log entries to display in the log view.
  final List<SpanLogEntry> spanLog;

  /// Whether a span operation is currently running.
  final bool isRunning;

  /// Creates a copy of this state with the given fields replaced.
  TracingPageUiState copyWith({
    List<SpanLogEntry>? spanLog,
    bool? isRunning,
  }) {
    return TracingPageUiState(
      spanLog: spanLog ?? this.spanLog,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  List<Object?> get props => [spanLog, isRunning];
}

// =============================================================================
// Actions Interface
// =============================================================================

/// Actions available on the tracing page.
///
/// This interface defines all user actions that can be performed,
/// making it easy to mock for testing and keeping the widget thin.
abstract interface class TracingPageActions {
  /// Clears all log entries.
  void clearLog();

  /// Runs a simple span with minimal configuration.
  Future<void> runSimpleSpan();

  /// Runs a span with string attributes.
  Future<void> runSpanWithStringAttributes();

  /// Runs a span with typed attributes (int, double, bool).
  Future<void> runSpanWithTypedAttributes();

  /// Runs a manual span where you control when it ends.
  Future<void> runManualSpan();

  /// Runs nested spans to demonstrate parent-child relationships.
  Future<void> runNestedSpans();

  /// Runs a span that records an error.
  Future<void> runSpanWithError();

  /// Demonstrates Span.noParent for independent traces.
  Future<void> runSpanWithNoParent();
}

// =============================================================================
// ViewModel
// =============================================================================

/// ViewModel for the tracing page.
///
/// Manages UI state and delegates business logic to the TracingService.
class _TracingPageViewModel extends Notifier<TracingPageUiState>
    implements TracingPageActions {
  // ---------------------------------------------------------------------------
  // Dependencies (initialized in build)
  // ---------------------------------------------------------------------------

  late TracingService _tracingService;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  TracingPageUiState build() {
    // Initialize dependencies
    _tracingService = ref.watch(tracingServiceProvider);

    return const TracingPageUiState(
      spanLog: [],
      isRunning: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Adds a log entry to the log view.
  ///
  /// This method conforms to [LogCallback] so it can be passed directly
  /// to [TracingService] methods.
  void _addLog(String message, {bool isError = false}) {
    state = state.copyWith(
      spanLog: [
        ...state.spanLog,
        SpanLogEntry(
          message: message,
          timestamp: DateTime.now(),
          isError: isError,
        ),
      ],
    );
  }

  /// Sets the running state.
  void _setRunning(bool running) {
    state = state.copyWith(isRunning: running);
  }

  /// Wraps a span operation with running state management.
  Future<void> _runSpanOperation(
    Future<void> Function(LogCallback log) operation,
  ) async {
    _setRunning(true);
    try {
      await operation(_addLog);
    } finally {
      _setRunning(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions Implementation
  // ---------------------------------------------------------------------------

  @override
  void clearLog() {
    state = state.copyWith(spanLog: const []);
  }

  @override
  Future<void> runSimpleSpan() async {
    await _runSpanOperation(_tracingService.runSimpleSpan);
  }

  @override
  Future<void> runSpanWithStringAttributes() async {
    await _runSpanOperation(_tracingService.runSpanWithStringAttributes);
  }

  @override
  Future<void> runSpanWithTypedAttributes() async {
    await _runSpanOperation(_tracingService.runSpanWithTypedAttributes);
  }

  @override
  Future<void> runManualSpan() async {
    await _runSpanOperation(_tracingService.runManualSpan);
  }

  @override
  Future<void> runNestedSpans() async {
    await _runSpanOperation(_tracingService.runNestedSpans);
  }

  @override
  Future<void> runSpanWithError() async {
    await _runSpanOperation(_tracingService.runSpanWithError);
  }

  @override
  Future<void> runSpanWithNoParent() async {
    await _runSpanOperation(_tracingService.runSpanWithNoParent);
  }
}

// =============================================================================
// Providers
// =============================================================================

final _tracingPageViewModelProvider =
    NotifierProvider<_TracingPageViewModel, TracingPageUiState>(
  _TracingPageViewModel.new,
);

/// Provider for the tracing page UI state.
///
/// Use this in widgets to reactively rebuild when state changes.
final tracingPageUiStateProvider = Provider<TracingPageUiState>((ref) {
  return ref.watch(_tracingPageViewModelProvider);
});

/// Provider for the tracing page actions.
///
/// Use this in widgets to trigger user actions.
final tracingPageActionsProvider = Provider<TracingPageActions>((ref) {
  return ref.read(_tracingPageViewModelProvider.notifier);
});
