import 'package:equatable/equatable.dart';
import 'package:faro_example/features/network_requests/domain/network_requests_demo_service.dart';
import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state for the network requests page.
class NetworkRequestsPageUiState extends Equatable {
  const NetworkRequestsPageUiState({
    required this.log,
    required this.isRunning,
  });

  final List<DemoLogEntry> log;
  final bool isRunning;

  NetworkRequestsPageUiState copyWith({
    List<DemoLogEntry>? log,
    bool? isRunning,
  }) {
    return NetworkRequestsPageUiState(
      log: log ?? this.log,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  List<Object?> get props => [log, isRunning];
}

/// Actions available on the network requests page.
abstract interface class NetworkRequestsPageActions {
  void clearLog();
  Future<void> sendPostSuccess();
  Future<void> sendPostFailure();
  Future<void> sendGetSuccess();
  Future<void> sendGetFailure();
}

class _NetworkRequestsPageViewModel extends Notifier<NetworkRequestsPageUiState>
    implements NetworkRequestsPageActions {
  late NetworkRequestsDemoService _service;

  @override
  NetworkRequestsPageUiState build() {
    _service = ref.watch(networkRequestsDemoServiceProvider);

    return const NetworkRequestsPageUiState(log: [], isRunning: false);
  }

  void _addLog(String message, {DemoLogTone tone = DemoLogTone.neutral}) {
    state = state.copyWith(
      log: [
        ...state.log,
        DemoLogEntry(message: message, timestamp: DateTime.now(), tone: tone),
      ],
    );
  }

  Future<void> _run(
    Future<void> Function(NetworkRequestLogCallback log) operation,
  ) async {
    state = state.copyWith(isRunning: true);
    try {
      await operation(_addLog);
    } finally {
      state = state.copyWith(isRunning: false);
    }
  }

  @override
  void clearLog() {
    state = state.copyWith(log: const []);
  }

  @override
  Future<void> sendPostSuccess() async {
    await _run(_service.sendPostSuccess);
  }

  @override
  Future<void> sendPostFailure() async {
    await _run(_service.sendPostFailure);
  }

  @override
  Future<void> sendGetSuccess() async {
    await _run(_service.sendGetSuccess);
  }

  @override
  Future<void> sendGetFailure() async {
    await _run(_service.sendGetFailure);
  }
}

final _viewModelProvider =
    NotifierProvider<_NetworkRequestsPageViewModel, NetworkRequestsPageUiState>(
      _NetworkRequestsPageViewModel.new,
    );

final networkRequestsPageUiStateProvider = Provider<NetworkRequestsPageUiState>(
  (ref) {
    return ref.watch(_viewModelProvider);
  },
);

final networkRequestsPageActionsProvider = Provider<NetworkRequestsPageActions>(
  (ref) {
    return ref.read(_viewModelProvider.notifier);
  },
);
