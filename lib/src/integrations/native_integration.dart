import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/models/log_level.dart';
import 'package:faro/src/models/measurement.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter/services.dart';

/// NativeIntegration provides access to native platform metrics and events
/// such as memory usage, CPU usage, ANR detection, and crash reporting.
class NativeIntegration implements Disposable {
  NativeIntegration({required TelemetryRouter telemetryRouter})
    : _telemetryRouter = telemetryRouter;

  final TelemetryRouter _telemetryRouter;
  final MethodChannel _channel = const MethodChannel('faro');

  int _warmStart = 0;
  Timer? _vitalsTimer;

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

  /// Cancels the periodic vitals timer and detaches the method channel
  /// handler.
  ///
  /// Invoked by dartypod when [nativeIntegrationProvider]'s scope is cleared.
  /// This instance is scoped to a single `Faro.init`; without teardown its
  /// timer would keep firing and holding the (now stale) telemetry router and
  /// session manager alive after `Faro.resetForTesting` or a re-init.
  ///
  /// Detaching the handler is safe because disposal always runs before the
  /// next `Faro.init` registers a new handler on the shared `'faro'` channel;
  /// it is never disposed after a newer instance has taken over.
  @override
  void dispose() {
    _vitalsTimer?.cancel();
    _vitalsTimer = null;
    _channel.setMethodCallHandler(null);
  }

  /// Pushes an SDK-emitted vitals measurement without extending inactivity.
  void _pushVitalsMeasurement(Map<String, dynamic>? values, String type) {
    _telemetryRouter.ingest(
      TelemetryItem.fromMeasurement(Measurement(values, type)),
      activity: SessionActivityKind.passive,
    );
  }

  /// Initialize refresh rate monitoring
  Future<void> initRefreshRate() async {
    try {
      await Faro().nativeChannel?.initRefreshRate();
    } catch (error) {
      log('Error initializing refresh rate: $error');
    }
  }

  /// Upper bound on a plausible user-visible cold start.
  ///
  /// Android rejects process starts it can show were not user-initiated, but
  /// iOS cannot detect a background launch at all. This bound is the backstop,
  /// and on iOS the only one: a launch longer than this is not something a
  /// user sat through, it is a process that was already alive long before
  /// anyone opened the app.
  ///
  /// Sixty seconds matches the bound in common use across mobile RUM tooling.
  /// A tighter bound would discard genuine slow launches on low-end devices
  /// without rejecting meaningfully more of the background starts this guards
  /// against, which run to hours.
  static const maxColdStartDuration = Duration(seconds: 60);

  /// Get app start metrics for cold start
  ///
  /// Emits nothing unless the duration is plausible and the platform reported
  /// the launch as user-visible. Android decides that from the process
  /// importance sampled at startup; iOS cannot tell a background launch apart,
  /// and only reports whether it found a usable anchor.
  Future<void> getAppStart() async {
    try {
      final appStart = await Faro().nativeChannel?.getAppStart();
      if (appStart == null) {
        return;
      }
      final durationMillis = appStart['appStartDurationMillis'];
      if (durationMillis is! int) {
        return;
      }
      if (appStart['isUserVisibleColdStart'] != true) {
        log(
          'Faro: discarding cold start, the process was not started by '
          'the user',
        );
        return;
      }
      if (durationMillis <= 0 ||
          durationMillis > maxColdStartDuration.inMilliseconds) {
        log('Faro: discarding implausible cold start of $durationMillis ms');
        return;
      }
      _pushVitalsMeasurement({
        'appStartDuration': durationMillis,
        'coldStart': 1,
        'prewarmed': appStart['prewarmed'] == true ? 1 : 0,
      }, 'app_startup');
    } catch (error) {
      log('Error getting app start metrics: $error');
    }
  }

  /// Set timestamp for warm start measurement
  void setWarmStart() {
    _warmStart = DateTime.now().millisecondsSinceEpoch;
  }

  /// Get app start metrics for warm start
  Future<void> getWarmStart() async {
    try {
      final warmStartDuration =
          DateTime.now().millisecondsSinceEpoch - _warmStart;
      if (warmStartDuration > 0) {
        _pushVitalsMeasurement({
          'appStartDuration': warmStartDuration,
          'coldStart': 0,
        }, 'app_startup');
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
      _vitalsTimer?.cancel();
      _vitalsTimer = Timer.periodic(setSendUsageInterval, (timer) {
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
    final refreshRate = await Faro().nativeChannel?.getRefreshRate();
    log('refreshRate $refreshRate');
    if (refreshRate != null) {
      _pushVitalsMeasurement({'refresh_rate': refreshRate}, 'app_refresh_rate');
    }
  }

  Future<void> _pushCpuUsage() async {
    final cpuUsage = await Faro().nativeChannel?.getCpuUsage();
    if (cpuUsage! > 0.0 && cpuUsage < 100.0) {
      _pushVitalsMeasurement({'cpu_usage': cpuUsage}, 'app_cpu_usage');
    }
  }

  Future<void> _getAnrStatus() async {
    final anr = await Faro().nativeChannel?.getANRStatus();

    if (anr != null && anr.isNotEmpty) {
      // Push the ANR count as a measurement
      _pushVitalsMeasurement({'anr_count': anr.length}, 'anr');

      // Log each ANR as a warning with its stacktrace
      for (final anrItem in anr) {
        try {
          // Parse the JSON string to extract just the stacktrace
          final anrJson = jsonDecode(anrItem);
          if (anrJson.containsKey('stacktrace')) {
            Faro().pushError(
              type: 'flutter_error',
              value: 'ANR (Application Not Responding)',
              context: {'stacktrace': anrJson['stacktrace']},
              fatal: true,
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _pushMemoryUsage() async {
    final memUsage = await Faro().nativeChannel?.getMemoryUsage();
    _pushVitalsMeasurement({'mem_usage': memUsage}, 'app_memory');
  }

  void initializeMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'lastCrashReport':
            if (call.arguments != null) {
              Faro().pushLog(call.arguments, level: LogLevel.error);
            }
            break;

          case 'onFrozenFrame':
            if (call.arguments != null) {
              _pushVitalsMeasurement({
                'frozen_frames': call.arguments,
              }, 'app_frozen_frame');
            }
            break;

          case 'onRefreshRate':
            if (call.arguments != null) {
              _pushVitalsMeasurement({
                'refresh_rate': call.arguments,
              }, 'app_refresh_rate');
            }
            break;

          case 'onSlowFrames':
            if (call.arguments != null) {
              _pushVitalsMeasurement({
                'slow_frames': call.arguments,
              }, 'app_frames_rate');
            }
            break;
        }
      } catch (error) {
        log('Error in method channel handler: $error');
      }
    });
  }
}

/// Provides the [NativeIntegration].
///
/// Lives in [faroInitScope] so each `Faro.init` gets a fresh instance
/// wired to the current telemetry router. Clearing the scope in
/// `Faro.resetForTesting` disposes it (see [NativeIntegration.dispose]),
/// cancelling the vitals timer so it cannot outlive its `Faro.init`.
final nativeIntegrationProvider = Provider<NativeIntegration>(
  (pod) =>
      NativeIntegration(telemetryRouter: pod.resolve(telemetryRouterProvider)),
  scope: faroInitScope,
);
