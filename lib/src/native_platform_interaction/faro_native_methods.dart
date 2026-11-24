import 'package:faro/src/native_platform_interaction/faro_sdk_platform_interface.dart';

class FaroNativeMethods {
  /// Reads the app process counters off the platform main thread.
  ///
  /// Always includes `monotonicNanos` and `timestampMillis` (wall-clock
  /// capture time, ms since the epoch). With [cpu], adds `cpuTimeSeconds` and
  /// `cpuCount`. With [memory], adds `memoryBytes` and `memoryBasis`. A
  /// counter that could not be read is left out.
  Future<Map<String, dynamic>?> getProcessVitals({
    required bool cpu,
    required bool memory,
  }) {
    return FaroSdkPlatform.instance.getProcessVitals(cpu: cpu, memory: memory);
  }

  /// Starts a short Android slow and frozen frame sampling window, or stops
  /// sampling when [enabled] is false.
  ///
  /// Android only starts a window while an activity is resumed and no window
  /// is running.
  Future<void> initFrameMonitoring({bool enabled = true}) {
    return FaroSdkPlatform.instance.initFrameMonitoring(enabled: enabled);
  }

  Future<Map<String, dynamic>?> getAppStart() {
    return FaroSdkPlatform.instance.getAppStart();
  }

  Future<Map<String, dynamic>?> getWarmStart() {
    return FaroSdkPlatform.instance.getWarmStart();
  }

  Future<Map<String, dynamic>?> stopFramesTracker() {
    return FaroSdkPlatform.instance.stopFramesTracker();
  }

  Future<void> startFramesTracker() {
    return FaroSdkPlatform.instance.startFramesTracker();
  }

  Future<List<String>?> getANRStatus() {
    return FaroSdkPlatform.instance.getANRStatus();
  }

  Future<void> enableCrashReporter(Map<String, dynamic> config) {
    return FaroSdkPlatform.instance.enableCrashReporter(config);
  }

  Future<List<String>?> getCrashReport() {
    return FaroSdkPlatform.instance.getCrashReport();
  }

  Future<void> purgeCrashReport() {
    return FaroSdkPlatform.instance.purgeCrashReport();
  }

  Future<Map<String, dynamic>?> getSessionRuntimeInfo({
    required bool claimSessionPersistence,
  }) {
    return FaroSdkPlatform.instance.getSessionRuntimeInfo(
      claimSessionPersistence: claimSessionPersistence,
    );
  }

  Future<Map<String, dynamic>?> getDeviceMetadata() {
    return FaroSdkPlatform.instance.getDeviceMetadata();
  }

  Future<Map<String, dynamic>?> getProbedDeviceState() {
    return FaroSdkPlatform.instance.getProbedDeviceState();
  }
}
