import 'rum_sdk_platform_interface.dart';

class RumNativeMethods{
  Future<double?> getMemoryUsage(){
    return RumSdkPlatform.instance.getMemoryUsage();
  }
  Future<double?> getRefreshRate(){
    return RumSdkPlatform.instance.getRefreshRate();
  }
  Future<void> initRefreshRate(){
    return RumSdkPlatform.instance.initRefreshRate();
  }
  Future<double?> getCpuUsage(){
    return RumSdkPlatform.instance.getCpuUsage();
  }
  Future<Map<String,dynamic>?> getAppStart(){
    return RumSdkPlatform.instance.getAppStart();
  }
  Future<Map<String,dynamic>?> getWarmStart(){
    return RumSdkPlatform.instance.getWarmStart();
  }
  Future<Map<String, dynamic>?> stopFramesTracker(){
    return RumSdkPlatform.instance.stopFramesTracker();
  }
  Future<void> startFramesTracker(){
    return RumSdkPlatform.instance.startFramesTracker();
  }
  Future<List<String>?> getANRStatus(){
    return RumSdkPlatform.instance.getANRStatus();
  }
  Future<void> enableCrashReporter( Map<String,dynamic> config){
    return RumSdkPlatform.instance.enableCrashReporter(config);
  }
  Future<List<String>?> getCrashReport(){
    return RumSdkPlatform.instance.getCrashReport();

  }
}

