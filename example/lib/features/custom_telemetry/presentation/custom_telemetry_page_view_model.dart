import 'package:equatable/equatable.dart';
import 'package:faro/faro.dart';
import 'package:faro_example/features/custom_telemetry/domain/custom_telemetry_demo_service.dart';
import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state for the custom telemetry page.
class CustomTelemetryPageUiState extends Equatable {
  const CustomTelemetryPageUiState({
    required this.log,
    required this.isDataCollectionEnabled,
  });

  final List<DemoLogEntry> log;
  final bool isDataCollectionEnabled;

  CustomTelemetryPageUiState copyWith({
    List<DemoLogEntry>? log,
    bool? isDataCollectionEnabled,
  }) {
    return CustomTelemetryPageUiState(
      log: log ?? this.log,
      isDataCollectionEnabled:
          isDataCollectionEnabled ?? this.isDataCollectionEnabled,
    );
  }

  @override
  List<Object?> get props => [log, isDataCollectionEnabled];
}

/// Actions available on the custom telemetry page.
abstract interface class CustomTelemetryPageActions {
  void clearLog();
  void emitWarnLog();
  void emitInfoLog();
  void emitErrorLog();
  void emitDebugLog();
  void emitTraceLog();
  void emitMeasurement();
  void emitEvent();
  void toggleDataCollection();
}

class _CustomTelemetryPageViewModel extends Notifier<CustomTelemetryPageUiState>
    implements CustomTelemetryPageActions {
  late CustomTelemetryDemoService _service;

  @override
  CustomTelemetryPageUiState build() {
    _service = ref.watch(customTelemetryDemoServiceProvider);

    return CustomTelemetryPageUiState(
      log: const [],
      isDataCollectionEnabled: Faro().enableDataCollection,
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
  void emitWarnLog() {
    _service.emitWarnLog(_addLog);
  }

  @override
  void emitInfoLog() {
    _service.emitInfoLog(_addLog);
  }

  @override
  void emitErrorLog() {
    _service.emitErrorLog(_addLog);
  }

  @override
  void emitDebugLog() {
    _service.emitDebugLog(_addLog);
  }

  @override
  void emitTraceLog() {
    _service.emitTraceLog(_addLog);
  }

  @override
  void emitMeasurement() {
    _service.emitMeasurement(_addLog);
  }

  @override
  void emitEvent() {
    _service.emitEvent(_addLog);
  }

  @override
  void toggleDataCollection() {
    final isEnabled = _service.toggleDataCollection(_addLog);
    state = state.copyWith(isDataCollectionEnabled: isEnabled);
  }
}

final _viewModelProvider =
    NotifierProvider<_CustomTelemetryPageViewModel, CustomTelemetryPageUiState>(
  _CustomTelemetryPageViewModel.new,
);

final customTelemetryPageUiStateProvider =
    Provider<CustomTelemetryPageUiState>((ref) {
  return ref.watch(_viewModelProvider);
});

final customTelemetryPageActionsProvider =
    Provider<CustomTelemetryPageActions>((ref) {
  return ref.read(_viewModelProvider.notifier);
});
