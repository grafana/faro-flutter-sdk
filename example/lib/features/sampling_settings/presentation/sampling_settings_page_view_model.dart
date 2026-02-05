import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sampling_settings_service.dart';
import '../models/sampling_setting.dart';

// =============================================================================
// UI State
// =============================================================================

/// Immutable UI state for the sampling settings page.
class SamplingSettingsPageUiState extends Equatable {
  const SamplingSettingsPageUiState({
    required this.selectedSetting,
    required this.isSessionSampled,
    required this.currentConfigDisplay,
    required this.needsRestart,
    required this.isLoading,
  });

  /// The currently selected sampling setting (persisted).
  final SamplingSetting selectedSetting;

  /// Whether the current session is sampled.
  final bool isSessionSampled;

  /// Display string for the current sampling config.
  final String currentConfigDisplay;

  /// Whether the app needs to restart to apply changes.
  final bool needsRestart;

  /// Whether data is still loading.
  final bool isLoading;

  /// Creates a copy of this state with the given fields replaced.
  SamplingSettingsPageUiState copyWith({
    SamplingSetting? selectedSetting,
    bool? isSessionSampled,
    String? currentConfigDisplay,
    bool? needsRestart,
    bool? isLoading,
  }) {
    return SamplingSettingsPageUiState(
      selectedSetting: selectedSetting ?? this.selectedSetting,
      isSessionSampled: isSessionSampled ?? this.isSessionSampled,
      currentConfigDisplay: currentConfigDisplay ?? this.currentConfigDisplay,
      needsRestart: needsRestart ?? this.needsRestart,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        selectedSetting,
        isSessionSampled,
        currentConfigDisplay,
        needsRestart,
        isLoading,
      ];
}

// =============================================================================
// Actions Interface
// =============================================================================

/// Actions available on the sampling settings page.
abstract interface class SamplingSettingsPageActions {
  /// Sets the sampling setting (persisted for next app start).
  Future<void> setSamplingSetting(SamplingSetting setting);
}

// =============================================================================
// ViewModel
// =============================================================================

/// ViewModel for the sampling settings page.
class _SamplingSettingsPageViewModel
    extends Notifier<SamplingSettingsPageUiState>
    implements SamplingSettingsPageActions {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  late SamplingSettingsService _service;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  SamplingSettingsPageUiState build() {
    _service = ref.watch(samplingSettingsServiceProvider);

    return SamplingSettingsPageUiState(
      selectedSetting: _service.samplingSetting,
      isSessionSampled: _service.isSessionSampled,
      currentConfigDisplay: _service.getCurrentSamplingDisplay(),
      needsRestart: _service.needsRestart,
      isLoading: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Actions Implementation
  // ---------------------------------------------------------------------------

  @override
  Future<void> setSamplingSetting(SamplingSetting setting) async {
    await _service.setSamplingSetting(setting);

    state = state.copyWith(
      selectedSetting: setting,
      needsRestart: _service.needsRestart,
    );
  }
}

// =============================================================================
// Providers
// =============================================================================

final _samplingSettingsPageViewModelProvider = NotifierProvider<
    _SamplingSettingsPageViewModel, SamplingSettingsPageUiState>(
  _SamplingSettingsPageViewModel.new,
);

/// Provider for the sampling settings page UI state.
///
/// Use this in widgets to reactively rebuild when state changes.
final samplingSettingsPageUiStateProvider =
    Provider<SamplingSettingsPageUiState>((ref) {
  return ref.watch(_samplingSettingsPageViewModelProvider);
});

/// Provider for the sampling settings page actions.
///
/// Use this in widgets to trigger user actions.
final samplingSettingsPageActionsProvider =
    Provider<SamplingSettingsPageActions>((ref) {
  return ref.read(_samplingSettingsPageViewModelProvider.notifier);
});
