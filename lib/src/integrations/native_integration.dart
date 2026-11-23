import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/process_vitals.dart';
import 'package:faro/src/models/event.dart';
import 'package:faro/src/models/log_level.dart';
import 'package:faro/src/models/measurement.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// NativeIntegration provides access to native platform metrics and events
/// such as app CPU and memory, ANR detection, and crash reporting.
class NativeIntegration with WidgetsBindingObserver implements Disposable {
  NativeIntegration({
    required TelemetryRouter telemetryRouter,
    @visibleForTesting bool? isAndroid,
  }) : _telemetryRouter = telemetryRouter,
       _isAndroidOverride = isAndroid;

  final TelemetryRouter _telemetryRouter;
  final bool? _isAndroidOverride;
  final MethodChannel _channel = const MethodChannel('faro');

  // Read lazily: this instance is also created on web, where `Platform`
  // throws. Only mobile code paths ask.
  bool get _isAndroid => _isAndroidOverride ?? Platform.isAndroid;

  int _warmStart = 0;
  Timer? _vitalsTimer;
  ProcessVitalsSampler? _processVitalsSampler;
  bool _observesLifecycle = false;

  /// The app CPU and memory sampler, once [init] has started it.
  @visibleForTesting
  ProcessVitalsSampler? get processVitalsSampler => _processVitalsSampler;

  /// Initialize the native integration with the specified features
  ///
  /// Parameters:
  /// - [memusage]: Emit `app.memory` events while the app is visible
  /// - [cpuusage]: Emit `app.cpu_usage` events while the app is visible
  /// - [anr]: Enable ANR (Application Not Responding) detection
  /// - [refreshrate]: On Android, calls the frame sampler initializer every
  ///   interval. A finished burst stays stopped until the next resume, so
  ///   this has no visible effect. No refresh rate is collected.
  /// - [setSendUsageInterval]: Interval of the vitals windows and ANR polling
  Future<void> init({
    bool? memusage,
    bool? cpuusage,
    bool? anr,
    bool? refreshrate,
    Duration? setSendUsageInterval,
  }) async {
    final interval = setSendUsageInterval ?? const Duration(seconds: 60);
    _scheduleCalls(
      anr: anr ?? false,
      refreshrate: refreshrate ?? false,
      setSendUsageInterval: interval,
    );
    _startProcessVitals(
      cpu: cpuusage ?? false,
      memory: memusage ?? false,
      interval: interval,
    );
    initFrameMonitoring();
    initializeMethodChannel();
  }

  /// Cancels the vitals timers and detaches the method channel handler and
  /// the lifecycle observer.
  ///
  /// Invoked by dartypod when [nativeIntegrationProvider]'s scope is cleared.
  /// This instance is scoped to a single `Faro.init`; without teardown its
  /// timers would keep firing and holding the (now stale) telemetry router
  /// and session manager alive after `Faro.resetForTesting` or a re-init.
  ///
  /// Detaching the handler is safe because disposal always runs before the
  /// next `Faro.init` registers a new handler on the shared `'faro'` channel;
  /// it is never disposed after a newer instance has taken over.
  @override
  void dispose() {
    _vitalsTimer?.cancel();
    _vitalsTimer = null;
    _processVitalsSampler?.dispose();
    _processVitalsSampler = null;
    if (_observesLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observesLifecycle = false;
    }
    _channel.setMethodCallHandler(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _processVitalsSampler?.onLifecycleStateChanged(state);
  }

  /// Pushes an SDK-emitted vitals measurement without extending inactivity.
  void _pushVitalsMeasurement(Map<String, dynamic>? values, String type) {
    _telemetryRouter.ingest(
      TelemetryItem.fromMeasurement(Measurement(values, type)),
      activity: SessionActivityKind.passive,
    );
  }

  /// Pushes an SDK-emitted vitals event without extending inactivity.
  ///
  /// The event bypasses user-action buffering, like `session_start`: a
  /// process sample describes the app, not the tap or flow in progress, and
  /// must not wait for that action to end.
  void _pushVitalsEvent(
    String name,
    Map<String, String> attributes,
    DateTime time,
  ) {
    final event = Event(name, attributes: attributes)
      ..timestamp = time.toUtc().toIso8601String();
    _telemetryRouter.ingest(
      TelemetryItem.fromEvent(event),
      activity: SessionActivityKind.passive,
      skipBuffer: true,
    );
  }

  void _startProcessVitals({
    required bool cpu,
    required bool memory,
    required Duration interval,
  }) {
    _processVitalsSampler?.dispose();
    _processVitalsSampler = null;
    if (!cpu && !memory) {
      return;
    }
    final sampler = ProcessVitalsSampler(
      reader: _readProcessVitals,
      emit: _pushVitalsEvent,
      interval: interval,
      cpuEnabled: cpu,
      memoryEnabled: memory,
    );
    _processVitalsSampler = sampler;
    if (!_observesLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observesLifecycle = true;
    }
    sampler.start(WidgetsBinding.instance.lifecycleState);
  }

  Future<ProcessVitalsReading?> _readProcessVitals({
    required bool cpu,
    required bool memory,
  }) async {
    final map = await Faro().nativeChannel?.getProcessVitals(
      cpu: cpu,
      memory: memory,
    );
    return ProcessVitalsReading.fromMap(map);
  }

  /// Starts the Android frame callback that counts slow and frozen frames.
  ///
  /// iOS has no frame sampler, so this does nothing there.
  Future<void> initFrameMonitoring() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await Faro().nativeChannel?.initFrameMonitoring();
    } catch (error) {
      log('Error initializing frame monitoring: $error');
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

  /// Runs ANR polling and, on Android, re-arms frame monitoring.
  ///
  /// Unlike CPU and memory, this keeps running while the app is hidden.
  void _scheduleCalls({
    bool anr = false,
    bool refreshrate = false,
    Duration setSendUsageInterval = const Duration(seconds: 60),
  }) {
    _vitalsTimer?.cancel();
    _vitalsTimer = null;
    if (!_isAndroid || !(anr || refreshrate)) {
      return;
    }
    _vitalsTimer = Timer.periodic(setSendUsageInterval, (timer) {
      if (anr) {
        _getAnrStatus();
      }
      if (refreshrate) {
        initFrameMonitoring();
      }
    });
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
