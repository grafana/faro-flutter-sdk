import 'package:faro/faro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sampling_setting.dart';

/// Service for managing sampling settings.
///
/// Handles loading, saving, and querying sampling configuration
/// that is passed to FaroConfig on app startup.
class SamplingSettingsService {
  SamplingSettingsService({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const String _samplingSettingKey = 'faro_sampling_setting';

  // ===========================================================================
  // Sampling Setting
  // ===========================================================================

  /// Gets the current sampling setting.
  SamplingSetting get samplingSetting {
    final storedName = _prefs.getString(_samplingSettingKey);
    if (storedName == null) {
      return SamplingSetting.all;
    }
    return SamplingSetting.values.firstWhere(
      (e) => e.name == storedName,
      orElse: () => SamplingSetting.all,
    );
  }

  /// Gets the [Sampling] configuration for the current setting.
  Sampling? get sampling => samplingSetting.sampling;

  /// Sets the sampling setting.
  Future<void> setSamplingSetting(SamplingSetting setting) async {
    if (setting == SamplingSetting.all) {
      await _prefs.remove(_samplingSettingKey);
    } else {
      await _prefs.setString(_samplingSettingKey, setting.name);
    }
  }

  // ===========================================================================
  // Current Session Info
  // ===========================================================================

  /// Gets whether the current session is sampled.
  bool get isSessionSampled => Faro().isSampled;

  /// Gets a display string for the current sampling config.
  String getCurrentSamplingDisplay() {
    final config = Faro().config;
    if (config == null) return 'Not initialized';

    final sampling = config.sampling;
    if (sampling == null) {
      return '100% (default)';
    }
    if (sampling is SamplingRate) {
      final percent = (sampling.rate * 100).toStringAsFixed(0);
      return 'SamplingRate($percent%)';
    }
    if (sampling is SamplingFunction) {
      return 'SamplingFunction';
    }
    return 'Unknown';
  }

  /// Gets the current session's sampling setting.
  ///
  /// This attempts to match the current config's sampling to a known setting.
  SamplingSetting? get currentSessionSamplingSetting {
    final config = Faro().config;
    if (config == null) return null;

    final currentSampling = config.sampling;

    // Match against known settings
    for (final setting in SamplingSetting.values) {
      if (_samplingMatches(currentSampling, setting)) {
        return setting;
      }
    }

    return null; // Unknown/custom sampling
  }

  /// Checks if the current config sampling matches a setting.
  bool _samplingMatches(Sampling? sampling, SamplingSetting setting) {
    if (sampling == null && setting == SamplingSetting.all) {
      return true;
    }
    if (sampling is SamplingRate) {
      switch (setting) {
        case SamplingSetting.none:
          return sampling.rate == 0.0;
        case SamplingSetting.half:
          return sampling.rate == 0.5;
        case SamplingSetting.tenPercent:
          return sampling.rate == 0.1;
        default:
          return false;
      }
    }
    // For SamplingFunction, we can't easily compare, so check by setting type
    if (sampling is SamplingFunction) {
      return setting.isFunction;
    }
    return false;
  }

  /// Returns true if the saved setting differs from current session.
  bool get needsRestart {
    final current = currentSessionSamplingSetting;
    if (current == null) return true; // Unknown config, restart to apply known
    return samplingSetting != current;
  }
}

// =============================================================================
// Provider
// =============================================================================

/// Provider for SharedPreferences instance.
///
/// Must be overridden with the actual instance at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with the actual instance',
  );
});

/// Provider for the sampling settings service.
final samplingSettingsServiceProvider = Provider<SamplingSettingsService>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SamplingSettingsService(prefs: prefs);
  },
);
