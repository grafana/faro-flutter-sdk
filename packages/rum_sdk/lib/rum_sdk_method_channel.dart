import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rum_sdk_platform_interface.dart';

/// An implementation of [RumSdkPlatform] that uses method channels.
class MethodChannelRumSdk extends RumSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rum_sdk');

  @override
  Future<void> initRefreshRate() async {
    await methodChannel.invokeMethod<void>('initRefreshRate');
  }

  @override
  Future<Map<String,dynamic>?> getAppStart() async {
    final appStart = await methodChannel.invokeMapMethod<String,dynamic>('getAppStart');
    return appStart;
  }

  @override
  Future<Map<String,dynamic>?> getWarmStart() async {
    final appStart = await methodChannel.invokeMapMethod<String,dynamic>('getWarmStart');
    return appStart;
  }
  @override
  Future<List<String>?> getANRStatus() async {
    final anr = await methodChannel.invokeListMethod<String>('getANRStatus');
    return anr;
  }


  @override
  Future<double?> getRefreshRate() async {
    final refreshRate = await methodChannel.invokeMethod<double?>('getRefreshRate');
    return refreshRate;
  }

  @override
  Future<double?> getMemoryUsage() async {
    return await methodChannel.invokeMethod<double?>('getMemoryUsage');
  }
  @override
  Future<double?> getCpuUsage() async {
    return await methodChannel.invokeMethod<double?>('getCpuUsage');
  }

  @override
  Future<String?> coldStart() async {
    final coldstart = await methodChannel.invokeMethod<String>('coldStart');
    return coldstart;
  }

  @override
  Future<String?> warmStart() async {
    final warmstart = await methodChannel.invokeMethod<String>('warmStart');
    return warmstart;
  }

    @override
  Future<void> enableCrashReporter(Map<String,dynamic> config) async {
    await methodChannel.invokeMethod<void>('enableCrashReporter',config);
  }
  @override
  Future<List<String>?>  getCrashReport() async {
    final crashInfo =  await methodChannel.invokeListMethod<String>('getCrashReport');
    return crashInfo;
  }
}
