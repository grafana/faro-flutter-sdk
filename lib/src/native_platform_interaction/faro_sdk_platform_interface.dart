import 'package:faro/src/native_platform_interaction/faro_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class FaroSdkPlatform extends PlatformInterface {
  /// Constructs a FaroSdkPlatform.
  FaroSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static FaroSdkPlatform _instance = MethodChannelFaroSdk();

  /// The default instance of [FaroSdkPlatform] to use.
  /// Defaults to [MethodChannelFaroSdk].
  static FaroSdkPlatform get instance => _instance;

  static set instance(FaroSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Map<String, dynamic>?> getAppStart() {
    throw UnimplementedError('getAppStart() has not been implemented.');
  }

  Future<Map<String, dynamic>?> getWarmStart() {
    throw UnimplementedError('getWarmStart() has not been implemented.');
  }

  Future<double?> getRefreshRate() {
    throw UnimplementedError('getRefreshRate() has not been implemented.');
  }

  Future<void> initRefreshRate() {
    throw UnimplementedError('initRefreshRate() has not been implemented.');
  }

  Future<String?> coldStart() {
    throw UnimplementedError('coldStart() has not been implemented.');
  }

  Future<String?> warmStart() {
    throw UnimplementedError('warmStart() has not been implemented.');
  }

  Future<double?> getMemoryUsage() {
    throw UnimplementedError('getMemoryUsage() has not been implemented.');
  }

  Future<double?> getCpuUsage() {
    throw UnimplementedError('getCpuUsage() has not been implemented.');
  }

  Future<void> startFramesTracker() {
    throw UnimplementedError('startFramesTracker() has not been implemented.');
  }

  Future<List<String>?> getANRStatus() {
    throw UnimplementedError('getANRStatus() has not been implemented.');
  }

// Test
  Future<Map<String, dynamic>?> stopFramesTracker() {
    throw UnimplementedError('stopFramesTracker() has not been implemented.');
  }

  Future<void> enableCrashReporter(Map<String, dynamic> config) {
    throw UnimplementedError('enableCrashReporter() has not been implemented.');
  }

  Future<List<String>?> getCrashReport() {
    throw UnimplementedError('getCrashReport() has not been implemented');
  }
}
