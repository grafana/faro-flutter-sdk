import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:rum_sdk/rum_flutter.dart';

/// NativeIntegration provides access to native platform metrics and events
/// such as memory usage, CPU usage, ANR detection, and crash reporting.
class NativeIntegration {
  final MethodChannel _channel = const MethodChannel('rum_sdk');

  static final NativeIntegration instance = NativeIntegration();
  static int warmStart = 0;

  /// Initialize the native integration with the specified features
  ///
  /// Parameters:
  /// - [memusage]: Enable memory usage tracking
  /// - [cpuusage]: Enable CPU usage tracking
  /// - [anr]: Enable ANR (Application Not Responding) detection
  /// - [refreshrate]: Enable refresh rate monitoring
  /// - [setSendUsageInterval]: Interval for sending usage metrics
  Future<void> init({
    bool? memusage,
    bool? cpuusage,
    bool? anr,
    bool? refreshrate,
    Duration? setSendUsageInterval,
  }) async {
    _scheduleCalls(
      memusage: memusage ?? false,
      cpuusage: cpuusage ?? false,
      anr: anr ?? false,
      refreshrate: refreshrate ?? false,
      setSendUsageInterval: setSendUsageInterval ?? const Duration(seconds: 60),
    );
    initRefreshRate();
    initializeMethodChannel();
  }

  /// Initialize refresh rate monitoring
  Future<void> initRefreshRate() async {
    try {
      await RumFlutter().nativeChannel?.initRefreshRate();
    } catch (error) {
      log('Error initializing refresh rate: $error');
    }
  }

  /// Get app start metrics for cold start
  Future<void> getAppStart() async {
    try {
      final appStart = await RumFlutter().nativeChannel?.getAppStart();
      if (appStart != null) {
        RumFlutter().pushMeasurement(
            {'appStartDuration': appStart['appStartDuration'], 'coldStart': 1},
            'app_startup');
      }
    } catch (error) {
      log('Error getting app start metrics: $error');
    }
  }

  /// Set timestamp for warm start measurement
  void setWarmStart() {
    warmStart = DateTime.now().millisecondsSinceEpoch;
  }

  /// Get app start metrics for warm start
  Future<void> getWarmStart() async {
    try {
      final warmStartDuration =
          DateTime.now().millisecondsSinceEpoch - warmStart;
      if (warmStartDuration > 0) {
        RumFlutter().pushMeasurement(
            {'appStartDuration': warmStartDuration, 'coldStart': 0},
            'app_startup');
      }
    } catch (error) {
      log('Error getting warm start metrics: $error');
    }
  }

  void _scheduleCalls({
    bool memusage = false,
    bool cpuusage = false,
    bool anr = false,
    bool refreshrate = false,
    Duration setSendUsageInterval = const Duration(seconds: 60),
  }) {
    if (memusage || cpuusage || anr || refreshrate) {
      Timer.periodic(setSendUsageInterval, (timer) {
        if (memusage) {
          _pushMemoryUsage();
        }
        if (cpuusage) {
          _pushCpuUsage();
        }
        if (anr && Platform.isAndroid) {
          _getAnrStatus();
        }
        if (refreshrate) {
          if (Platform.isAndroid) {
            initRefreshRate();
          } else {
            _pushRefreshRate();
          }
        }
      });
    }
  }

  Future<void> _pushRefreshRate() async {
    final refreshRate = await RumFlutter().nativeChannel?.getRefreshRate();
    log('refreshRate $refreshRate');
    if (refreshRate != null) {
      RumFlutter()
          .pushMeasurement({'refresh_rate': refreshRate}, 'app_refresh_rate');
    }
  }

  Future<void> _pushCpuUsage() async {
    final cpuUsage = await RumFlutter().nativeChannel?.getCpuUsage();
    if (cpuUsage! > 0.0 && cpuUsage < 100.0) {
      RumFlutter().pushMeasurement({'cpu_usage': cpuUsage}, 'app_cpu_usage');
    }
  }

  Future<void> _getAnrStatus() async {
    final anr = await RumFlutter().nativeChannel?.getANRStatus();

    if (anr != null && anr.isNotEmpty) {
      // Push the ANR count as a measurement
      RumFlutter().pushMeasurement({'anr_count': anr.length}, 'anr');

      // Log each ANR as a warning with its stacktrace
      for (final anrItem in anr) {
        try {
          // Parse the JSON string to extract just the stacktrace
          final anrJson = jsonDecode(anrItem);
          if (anrJson.containsKey('stacktrace')) {
            RumFlutter().pushError(
              type: 'flutter_error',
              value: 'ANR (Application Not Responding)',
              context: {'stacktrace': anrJson['stacktrace']},
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _pushMemoryUsage() async {
    final memUsage = await RumFlutter().nativeChannel?.getMemoryUsage();
    RumFlutter().pushMeasurement({'mem_usage': memUsage}, 'app_memory');
  }

  static void initializeMethodChannel() {
    instance._channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'lastCrashReport':
            if (call.arguments != null) {
              RumFlutter().pushLog(call.arguments, level: 'error');
            }
            break;

          case 'onFrozenFrame':
            if (call.arguments != null) {
              RumFlutter().pushMeasurement({
                'frozen_frames': call.arguments,
              }, 'app_frozen_frame');
            }
            break;

          case 'onRefreshRate':
            if (call.arguments != null) {
              RumFlutter().pushMeasurement({
                'refresh_rate': call.arguments,
              }, 'app_refresh_rate');
            }
            break;

          case 'onSlowFrames':
            if (call.arguments != null) {
              RumFlutter().pushMeasurement(
                  {'slow_frames': call.arguments}, 'app_frames_rate');
            }
            break;
        }
      } catch (error) {
        log('Error in method channel handler: $error');
      }
    });
  }
}
