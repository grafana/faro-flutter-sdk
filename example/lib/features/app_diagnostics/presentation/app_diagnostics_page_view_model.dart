import 'package:equatable/equatable.dart';
import 'package:faro_example/features/app_diagnostics/domain/app_diagnostics_demo_service.dart';
import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state for the app diagnostics page.
class AppDiagnosticsPageUiState extends Equatable {
  const AppDiagnosticsPageUiState({
    required this.log,
    required this.isRunning,
  });

  final List<DemoLogEntry> log;
  final bool isRunning;

  AppDiagnosticsPageUiState copyWith({
    List<DemoLogEntry>? log,
    bool? isRunning,
  }) {
    return AppDiagnosticsPageUiState(
      log: log ?? this.log,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  List<Object?> get props => [log, isRunning];
}

/// Actions available on the app diagnostics page.
abstract interface class AppDiagnosticsPageActions {
  void clearLog();
  void triggerUnhandledError();
  void triggerUnhandledException();
  Future<void> simulateAnr(int seconds);
}

class _AppDiagnosticsPageViewModel extends Notifier<AppDiagnosticsPageUiState>
    implements AppDiagnosticsPageActions {
  late AppDiagnosticsDemoService _service;

  @override
  AppDiagnosticsPageUiState build() {
    _service = ref.watch(appDiagnosticsDemoServiceProvider);

    return const AppDiagnosticsPageUiState(
      log: [],
      isRunning: false,
    );
  }

  void _addLog(
    String message, {
    DemoLogTone tone = DemoLogTone.neutral,
  }) {
    state = state.copyWith(
      log: [
        ...state.log,
        DemoLogEntry(
          message: message,
          timestamp: DateTime.now(),
          tone: tone,
        ),
      ],
    );
  }

  @override
  void clearLog() {
    state = state.copyWith(log: const []);
  }

  @override
  void triggerUnhandledError() {
    _service.triggerUnhandledError(_addLog);
  }

  @override
  void triggerUnhandledException() {
    _service.triggerUnhandledException(_addLog);
  }

  @override
  Future<void> simulateAnr(int seconds) async {
    state = state.copyWith(isRunning: true);
    try {
      await _service.simulateAnr(seconds: seconds, log: _addLog);
    } finally {
      state = state.copyWith(isRunning: false);
    }
  }
}

final _viewModelProvider =
    NotifierProvider<_AppDiagnosticsPageViewModel, AppDiagnosticsPageUiState>(
  _AppDiagnosticsPageViewModel.new,
);

final appDiagnosticsPageUiStateProvider =
    Provider<AppDiagnosticsPageUiState>((ref) {
  return ref.watch(_viewModelProvider);
});

final appDiagnosticsPageActionsProvider =
    Provider<AppDiagnosticsPageActions>((ref) {
  return ref.read(_viewModelProvider.notifier);
});
