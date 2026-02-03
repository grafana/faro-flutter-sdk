import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/models/faro_user.dart';
import 'package:faro/src/transport/faro_transport.dart';

class FaroConfig {
  FaroConfig({
    required this.appName,
    required this.appEnv,
    required this.apiKey,
    required this.collectorUrl,
    this.appVersion,
    this.namespace,
    this.transports,
    this.enableFlutterErrorReporting = true,
    this.enableCrashReporting = false,
    this.memoryUsageVitals = true,
    this.cpuUsageVitals = true,
    this.anrTracking = false,
    this.refreshRateVitals = false,
    this.fetchVitalsInterval = const Duration(seconds: 30),
    BatchConfig? batchConfig,
    this.ignoreUrls,
    this.maxBufferLimit = 30,
    this.collectorHeaders,
    this.sessionAttributes,
    this.initialUser,
    this.persistUser = true,
    this.samplingRate = 1.0,
  })  : assert(appName.isNotEmpty, 'appName cannot be empty'),
        assert(appEnv.isNotEmpty, 'appEnv cannot be empty'),
        assert(apiKey.isNotEmpty, 'apiKey cannot be empty'),
        assert(maxBufferLimit > 0, 'maxBufferLimit must be greater than 0'),
        assert(
          samplingRate >= 0.0 && samplingRate <= 1.0,
          'samplingRate must be between 0.0 and 1.0',
        ),
        batchConfig = batchConfig ?? BatchConfig();
  final String appName;
  final String appEnv;
  final String apiKey;
  final String? appVersion;
  final String? namespace;
  final String? collectorUrl;
  final Map<String, String>? collectorHeaders;
  final List<FaroTransport>? transports;
  final bool memoryUsageVitals;
  final bool cpuUsageVitals;
  final bool anrTracking;
  final bool enableCrashReporting;
  final bool enableFlutterErrorReporting;
  final bool refreshRateVitals;
  final BatchConfig batchConfig;
  final int maxBufferLimit;
  final Duration? fetchVitalsInterval;
  final List<RegExp>? ignoreUrls;

  /// Custom attributes to include in all session data.
  ///
  /// These attributes are applied to:
  /// - **Faro session** (`meta.session.attributes`): Values are converted to
  ///   strings as required by the Faro protocol
  /// - **Span resources** (`resource.attributes`): Types are preserved
  ///   (String, int, double, bool), enabling numeric queries and filtering
  ///
  /// Attributes are merged with default device attributes and included
  /// in all telemetry data.
  final Map<String, Object>? sessionAttributes;

  /// User to set immediately on initialization.
  ///
  /// - If provided, takes precedence over any persisted user
  /// - Use [FaroUser.cleared] to explicitly start with no user
  /// - If `null` (default), uses persisted user if available
  final FaroUser? initialUser;

  /// Whether to persist user data between app sessions.
  ///
  /// When enabled (default), the user set via [Faro.setUser] will be
  /// automatically restored on the next app start, ensuring early
  /// telemetry events include user identification.
  ///
  /// Set to `false` to disable user persistence.
  final bool persistUser;

  /// Session sampling rate (0.0 to 1.0, default: 1.0 = 100%).
  ///
  /// Controls the probability that a session will be sampled. When a session
  /// is not sampled, no telemetry (events, logs, exceptions, measurements,
  /// traces) is sent for that session.
  ///
  /// Examples:
  /// - `1.0` (default): 100% of sessions are sampled (all telemetry sent)
  /// - `0.5`: 50% of sessions are sampled
  /// - `0.0`: 0% of sessions are sampled (no telemetry sent)
  ///
  /// The sampling decision is made once per session at initialization time.
  final double samplingRate;
}
