import 'package:faro/src/native_platform_interaction/faro_sdk_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [FaroSdkPlatform] that uses method channels.
class MethodChannelFaroSdk extends FaroSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('faro');

  @override
  Future<void> initRefreshRate() async {
    await methodChannel.invokeMethod<void>('initRefreshRate');
  }

  @override
  Future<Map<String, dynamic>?> getAppStart() async {
    final appStart =
        await methodChannel.invokeMapMethod<String, dynamic>('getAppStart');
    return appStart;
  }

  @override
  Future<Map<String, dynamic>?> getWarmStart() async {
    final appStart =
        await methodChannel.invokeMapMethod<String, dynamic>('getWarmStart');
    return appStart;
  }

  @override
  Future<List<String>?> getANRStatus() async {
    final anr = await methodChannel.invokeListMethod<String>('getANRStatus');
    return anr;
  }

  @override
  Future<double?> getRefreshRate() async {
    final refreshRate =
        await methodChannel.invokeMethod<double?>('getRefreshRate');
    return refreshRate;
  }

  @override
  Future<double?> getMemoryUsage() async {
    return methodChannel.invokeMethod<double?>('getMemoryUsage');
  }

  @override
  Future<double?> getCpuUsage() async {
    return methodChannel.invokeMethod<double?>('getCpuUsage');
  }

  @override
  Future<String?> coldStart() async {
    final coldStart = await methodChannel.invokeMethod<String>('coldStart');
    return coldStart;
  }

  @override
  Future<String?> warmStart() async {
    final warmStart = await methodChannel.invokeMethod<String>('warmStart');
    return warmStart;
  }

  @override
  Future<void> enableCrashReporter(Map<String, dynamic> config) async {
    await methodChannel.invokeMethod<void>('enableCrashReporter', config);
  }

  @override
  Future<List<String>?> getCrashReport() async {
    final crashInfo =
        await methodChannel.invokeListMethod<String>('getCrashReport');
    return crashInfo;
  }
}
