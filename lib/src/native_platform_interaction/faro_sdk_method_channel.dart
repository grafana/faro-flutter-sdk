import 'package:faro/src/native_platform_interaction/faro_sdk_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [FaroSdkPlatform] that uses method channels.
class MethodChannelFaroSdk extends FaroSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('faro');

  @override
  Future<void> initFrameMonitoring({bool enabled = true}) async {
    await methodChannel.invokeMethod<void>('initFrameMonitoring', enabled);
  }

  @override
  Future<Map<String, dynamic>?> getAppStart() async {
    final appStart = await methodChannel.invokeMapMethod<String, dynamic>(
      'getAppStart',
    );
    return appStart;
  }

  @override
  Future<Map<String, dynamic>?> getWarmStart() async {
    final appStart = await methodChannel.invokeMapMethod<String, dynamic>(
      'getWarmStart',
    );
    return appStart;
  }

  @override
  Future<List<String>?> getANRStatus() async {
    final anr = await methodChannel.invokeListMethod<String>('getANRStatus');
    return anr;
  }

  @override
  Future<Map<String, dynamic>?> getProcessVitals({
    required bool cpu,
    required bool memory,
  }) {
    return methodChannel.invokeMapMethod<String, dynamic>(
      'getProcessVitals',
      <String, dynamic>{'cpu': cpu, 'memory': memory},
    );
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
    final crashInfo = await methodChannel.invokeListMethod<String>(
      'getCrashReport',
    );
    return crashInfo;
  }

  @override
  Future<void> purgeCrashReport() async {
    await methodChannel.invokeMethod<void>('purgeCrashReport');
  }

  @override
  Future<Map<String, dynamic>?> getSessionRuntimeInfo({
    required bool claimSessionPersistence,
  }) {
    return methodChannel.invokeMapMethod<String, dynamic>(
      'getSessionRuntimeInfo',
      <String, dynamic>{'claimSessionPersistence': claimSessionPersistence},
    );
  }

  @override
  Future<Map<String, dynamic>?> getDeviceMetadata() {
    return methodChannel.invokeMapMethod<String, dynamic>('getDeviceMetadata');
  }

  @override
  Future<Map<String, dynamic>?> getProbedDeviceState() {
    return methodChannel.invokeMapMethod<String, dynamic>(
      'getProbedDeviceState',
    );
  }
}
