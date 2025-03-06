import 'package:faro/faro_sdk_platform_interface.dart';

class FaroNativeMethods {
  Future<double?> getMemoryUsage() {
    return FaroSdkPlatform.instance.getMemoryUsage();
  }

  Future<double?> getRefreshRate() {
    return FaroSdkPlatform.instance.getRefreshRate();
  }

  Future<void> initRefreshRate() {
    return FaroSdkPlatform.instance.initRefreshRate();
  }

  Future<double?> getCpuUsage() {
    return FaroSdkPlatform.instance.getCpuUsage();
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
}
