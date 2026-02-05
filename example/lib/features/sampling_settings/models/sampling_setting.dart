import 'package:faro/faro.dart';

/// Enum representing the sampling options for FaroConfig.
///
/// These presets demonstrate different sampling configurations:
/// - Fixed rate sampling with [SamplingRate]
/// - Dynamic function-based sampling with [SamplingFunction]
enum SamplingSetting {
  /// Sample all sessions (100%) - default behavior.
  all,

  /// Sample no sessions (0%) - disable telemetry.
  none,

  /// Sample half of sessions (50%).
  half,

  /// Sample 10% of sessions.
  tenPercent,

  /// Dynamic: Sample 100% of admin users (role='admin'), 10% of others.
  adminUsers;

  /// Get the [Sampling] configuration for this setting.
  Sampling? get sampling {
    switch (this) {
      case SamplingSetting.all:
        return null; // null means 100% sampling (default)
      case SamplingSetting.none:
        return const SamplingRate(0.0);
      case SamplingSetting.half:
        return const SamplingRate(0.5);
      case SamplingSetting.tenPercent:
        return const SamplingRate(0.1);
      case SamplingSetting.adminUsers:
        return SamplingFunction((context) {
          // Sample all admin users (e.g., jane.smith)
          if (context.meta.user?.attributes?['role'] == 'admin') {
            return 1.0;
          }
          // Sample 10% of others
          return 0.1;
        });
    }
  }

  /// Returns the display name for this setting.
  String get displayName {
    switch (this) {
      case SamplingSetting.all:
        return '100% (All sessions)';
      case SamplingSetting.none:
        return '0% (No sessions)';
      case SamplingSetting.half:
        return '50% (Half)';
      case SamplingSetting.tenPercent:
        return '10%';
      case SamplingSetting.adminUsers:
        return 'Admin Users Priority';
    }
  }

  /// Returns a subtitle description for this setting.
  String get subtitle {
    switch (this) {
      case SamplingSetting.all:
        return 'Default - samples every session';
      case SamplingSetting.none:
        return 'Disables all telemetry collection';
      case SamplingSetting.half:
        return 'SamplingRate(0.5)';
      case SamplingSetting.tenPercent:
        return 'SamplingRate(0.1)';
      case SamplingSetting.adminUsers:
        return 'SamplingFunction: 100% admin users, 10% others';
    }
  }

  /// Returns the type label for display (Rate vs Function).
  String get typeLabel {
    switch (this) {
      case SamplingSetting.all:
      case SamplingSetting.none:
      case SamplingSetting.half:
      case SamplingSetting.tenPercent:
        return 'Rate';
      case SamplingSetting.adminUsers:
        return 'Function';
    }
  }

  /// Whether this is a function-based sampler.
  bool get isFunction {
    switch (this) {
      case SamplingSetting.all:
      case SamplingSetting.none:
      case SamplingSetting.half:
      case SamplingSetting.tenPercent:
        return false;
      case SamplingSetting.adminUsers:
        return true;
    }
  }
}
