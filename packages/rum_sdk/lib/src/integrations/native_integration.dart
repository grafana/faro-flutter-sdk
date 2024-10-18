import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:rum_sdk/rum_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';


class NativeIntegration{
  final MethodChannel _channel = const MethodChannel('rum_sdk');

  static final NativeIntegration instance = NativeIntegration();
  static int warmStart = 0;

  void init({bool? memusage, bool? cpuusage, bool? anr, bool? refreshrate, Duration? setSendUsageInterval}){
    _scheduleCalls(memusage: memusage?? false, cpuusage: cpuusage?? false, anr: anr?? false, refreshrate: refreshrate?? false , setSendUsageInterval: setSendUsageInterval?? const Duration(seconds: 60));
    initRefreshRate();
    initializeMethodChannel();
  }

  void initRefreshRate() async {
      await RumFlutter().nativeChannel?.initRefreshRate();
  }

  void getAppStart() async {
      Map<String, dynamic>? appStart = await RumFlutter().nativeChannel
          ?.getAppStart();
      RumFlutter().pushMeasurement({
        "appStartDuration": appStart!["appStartDuration"],
        "coldStart": 1
      }, "app_startup");
  }
  void setWarmStart() {
    warmStart = DateTime.now().millisecondsSinceEpoch;
  }
  void getWarmStart() async {
      int warmStartDuration = DateTime.now().millisecondsSinceEpoch - warmStart;
      if(warmStartDuration>0){
        RumFlutter().pushMeasurement({
          "appStartDuration":warmStartDuration,
          "coldStart": 0
        },"app_startup");
      }
  }

  @visibleForTesting
  void _scheduleCalls({
    bool memusage=false,
    bool cpuusage=false,
    bool anr=false,
    bool refreshrate = false,
    Duration setSendUsageInterval = const Duration(seconds: 60) }) {
    if(memusage || cpuusage || anr || refreshrate){
      Timer.periodic(setSendUsageInterval, (timer) {
        if(memusage) {
          _pushMemoryUsage();
        }
        if(cpuusage){
          _pushCpuUsage();
        }
        if(anr && Platform.isAndroid) {
          _getAnrStatus();
        }
        if(refreshrate){
          if(Platform.isAndroid){
            initRefreshRate();
          }else{
            _pushRefreshRate();
          }
        }

      });
    }
  }

  void _pushRefreshRate() async{
    double? refreshRate = await RumFlutter().nativeChannel?.getRefreshRate();
    log("refreshRate $refreshRate");
    if(refreshRate != null){
      RumFlutter().pushMeasurement({
        "refresh_rate" :refreshRate
      },"app_refresh_rate");
    }

  }

  void _pushCpuUsage() async {
    double? cpuUsage = await RumFlutter().nativeChannel?.getCpuUsage();
    if(cpuUsage!>0.0 && cpuUsage<100.0){
      RumFlutter().pushMeasurement({
        "cpu_usage" :cpuUsage
      },"app_cpu_usage");
    }
  }
  void _getAnrStatus() async {
    List<String>? anr = await RumFlutter().nativeChannel?.getANRStatus();
    if(anr !=null && anr.length>0){
      RumFlutter().pushMeasurement({
        "anr_count" :anr.length
      },"anr");
    }
  }
  void _pushMemoryUsage() async {
    double? memUsage = await RumFlutter().nativeChannel?.getMemoryUsage();
    RumFlutter().pushMeasurement({
      "mem_usage" :memUsage
    },"app_memory");
  }

  static void initializeMethodChannel() {
    instance._channel.setMethodCallHandler((MethodCall call) async {
      if(call.method == 'lastCrashReport'){
        RumFlutter().pushLog(call.arguments,level: "error");
      }
      if (call.method == 'onFrozenFrame') {

        if(call.arguments != null) {
          RumFlutter().pushMeasurement({
            "frozen_frames": call.arguments,
          }, "app_frozen_frame");
        }
      }
      if (call.method == 'onRefreshRate') {
        if(call.arguments !=null) {
          RumFlutter().pushMeasurement({
            "refresh_rate": call.arguments,
          }, "app_refresh_rate");
          // Handle the message from Java
        }
      }
      if (call.method == 'onSlowFrames') {
        if(call.arguments!=null){
          RumFlutter().pushMeasurement({
            "slow_frames" :call.arguments
          },"app_frames_rate");
        }

      }

    });
  }

}