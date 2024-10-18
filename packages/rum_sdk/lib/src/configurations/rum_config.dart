import 'package:rum_sdk/rum_sdk.dart';

import './batch_config.dart';
class RumConfig {
  final String appName;
  final String appEnv;
  final String apiKey;
  final String? appVersion;
  final String? collectorUrl;
  final List<RUMTransport>? transports;
  final bool memoryUsageVitals;
  final bool cpuUsageVitals;
  final bool anrTracking;
  final bool enableCrashReporting;
  final bool refreshRateVitals;
  final BatchConfig batchConfig;
  final int maxBufferLimit;
  final Duration? fetchVitalsInterval;
  final List<RegExp>? ignoreUrls;

  RumConfig({
    required this.appName,
    required this.appEnv,
    required this.apiKey,
    required this.collectorUrl,
    this.appVersion,
    this.transports,
    this.enableCrashReporting = false,
    this.memoryUsageVitals = true,
    this.cpuUsageVitals = true,
    this.anrTracking = false,
    this.refreshRateVitals = false,
    this.fetchVitalsInterval = const Duration(seconds: 30),
    BatchConfig? batchConfig,
    this.ignoreUrls,
    this.maxBufferLimit = 30,
  })  : assert(appName.isNotEmpty, 'appName cannot be empty'),
        assert(appEnv.isNotEmpty, 'appEnv cannot be empty'),
        assert(apiKey.isNotEmpty, 'apiKey cannot be empty'),
        assert(maxBufferLimit > 0, 'maxBufferLimit must be greater than 0'),
        this.batchConfig = batchConfig ?? BatchConfig();

// Other methods or properties of RumConfig can be added here
}