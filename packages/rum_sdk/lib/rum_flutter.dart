import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:rum_sdk/rum_native_methods.dart';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/data_collection_policy.dart';
import 'package:rum_sdk/src/device_info/session_attributes_provider.dart';
import 'package:rum_sdk/src/models/span_record.dart';
import 'package:rum_sdk/src/tracing/tracer_provider.dart';
import 'package:rum_sdk/src/transport/batch_transport.dart';
import 'package:rum_sdk/src/util/generate_session.dart';

Timer? timer;

typedef AppRunner = FutureOr<void> Function();

class RumFlutter {
  factory RumFlutter() {
    return _instance;
  }
  // Private constructor
  RumFlutter._();

  // Singleton instance
  static RumFlutter _instance = RumFlutter._();

  @visibleForTesting
  static set instance(RumFlutter instance) => _instance = instance;

  bool get enableDataCollection => DataCollectionPolicy().isEnabled;
  set enableDataCollection(bool enable) {
    if (enable) {
      DataCollectionPolicy().enable();
    } else {
      DataCollectionPolicy().disable();
    }
  }

  RumConfig? config;
  List<BaseTransport> _transports = [];
  BatchTransport? _batchTransport;
  List<BaseTransport> get transports => _transports;

  Meta meta = Meta(
      session: Session(generateSessionID(), attributes: {}),
      sdk: Sdk('rum-flutter', '1.3.5', []),
      app: App('', '', ''),
      view: ViewMeta('default'));

  List<RegExp>? ignoreUrls = [];
  Map<String, dynamic> eventMark = {};
  RumNativeMethods? _nativeChannel;

  RumNativeMethods? get nativeChannel => _nativeChannel;

  @visibleForTesting
  set nativeChannel(RumNativeMethods? nativeChannel) {
    _nativeChannel = nativeChannel;
  }

  @visibleForTesting
  set transports(List<BaseTransport> transports) {
    _transports = transports;
  }

  @visibleForTesting
  set batchTransport(BatchTransport? batchTransport) {
    _batchTransport = batchTransport;
  }

  Future<void> init({required RumConfig optionsConfiguration}) async {
    final attributesProvider =
        await SessionAttributesProviderFactory().create();
    meta.session?.attributes = await attributesProvider.getAttributes();

    _nativeChannel ??= RumNativeMethods();
    config = optionsConfiguration;
    _batchTransport = _batchTransport ??
        BatchTransport(
            payload: Payload(meta),
            batchConfig: config?.batchConfig ?? BatchConfig(),
            transports: _transports);

    if (config?.transports == null) {
      RumFlutter()._transports.add(
            RUMTransport(
              collectorUrl: optionsConfiguration.collectorUrl ?? '',
              apiKey: optionsConfiguration.apiKey,
              maxBufferLimit: config?.maxBufferLimit,
              sessionId: meta.session?.id,
            ),
          );
    } else {
      RumFlutter()._transports.addAll(config?.transports ?? []);
    }
    _instance.ignoreUrls = optionsConfiguration.ignoreUrls ?? [];
    final packageInfo = await PackageInfo.fromPlatform();
    _instance.setAppMeta(
        appName: optionsConfiguration.appName,
        appEnv: optionsConfiguration.appEnv,
        appVersion: optionsConfiguration.appVersion == null
            ? packageInfo.version
            : optionsConfiguration.appVersion!);
    if (config?.enableCrashReporting == true) {
      _instance.enableCrashReporter(
        app: _instance.meta.app!,
        apiKey: optionsConfiguration.apiKey,
        collectorUrl: optionsConfiguration.collectorUrl ?? '',
      );
    }
    if (Platform.isAndroid || Platform.isIOS) {
      NativeIntegration.instance.init(
          memusage: optionsConfiguration.memoryUsageVitals,
          cpuusage: optionsConfiguration.cpuUsageVitals,
          anr: optionsConfiguration.anrTracking,
          refreshrate: optionsConfiguration.refreshRateVitals,
          setSendUsageInterval: optionsConfiguration.fetchVitalsInterval);
    }
    await _instance.pushEvent('session_start');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NativeIntegration.instance.getAppStart();
    });
    WidgetsBinding.instance.addObserver(RumWidgetsBindingObserver());
  }

  Future<void> runApp(
      {required RumConfig optionsConfiguration,
      required AppRunner? appRunner}) async {
    OnErrorIntegration().call();
    FlutterErrorIntegration().call();
    await init(optionsConfiguration: optionsConfiguration);
    await appRunner!();
  }

  void setAppMeta(
      {required String appName,
      required String appEnv,
      required String appVersion}) {
    final appMeta = App(appName, appEnv, appVersion);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), 'app': appMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void setUserMeta({String? userId, String? userName, String? userEmail}) {
    final userMeta = User(id: userId, username: userName, email: userEmail);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), 'user': userMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void setViewMeta({String? name}) {
    final viewMeta = ViewMeta(name);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), 'view': viewMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  Future<void>? pushEvent(
    String name, {
    Map<String, dynamic>? attributes,
    Map<String, String>? trace,
  }) {
    _batchTransport?.addEvent(Event(
      name,
      attributes: attributes,
      trace: trace,
    ));
    return null;
  }

  Future<void>? pushLog(
    String message, {
    String? level,
    Map<String, dynamic>? context,
    Map<String, String>? trace,
  }) {
    _batchTransport?.addLog(
      RumLog(message, level: level, context: context, trace: trace),
    );
    return null;
  }

  Future<void> pushSpan(SpanRecord spanRecord) async {
    _batchTransport?.addSpan(spanRecord);
  }

  Future<void>? pushError({
    required String type,
    required String value,
    StackTrace? stacktrace,
    Map<String, String>? context,
  }) {
    var parsedStackTrace = <String, dynamic>{};
    if (stacktrace != null) {
      parsedStackTrace = {'frames': RumException.stackTraceParse(stacktrace)};
    }
    _batchTransport?.addExceptions(
      RumException(type, value, parsedStackTrace, context: context),
    );
    return null;
  }

  Future<void>? pushMeasurement(Map<String, dynamic>? values, String type) {
    _batchTransport?.addMeasurement(Measurement(values, type));
    return null;
  }

  Tracer getTracer() {
    return DartOtelTracerProvider().getTracer();
  }

  void markEventStart(String key, String name) {
    final eventStartTime = DateTime.now().millisecondsSinceEpoch;
    eventMark[key] = {
      'eventName': name,
      'eventStartTime': eventStartTime,
    };
  }

  Future<void>? markEventEnd(String key, String name,
      {Map<String, dynamic> attributes = const {}}) {
    final eventEndTime = DateTime.now().millisecondsSinceEpoch;
    if (name == 'http_request' && ignoreUrls != null) {
      if (ignoreUrls!
          .any((element) => element.stringMatch(attributes['url']) != null)) {
        return null;
      }
    }
    if (!eventMark.containsKey(key)) {
      return null;
    }
    final duration = eventEndTime - eventMark[key]['eventStartTime'];
    pushEvent(name, attributes: {
      ...attributes,
      'duration': duration.toString(),
      'eventStart': eventMark[key]['eventStartTime'].toString(),
      'eventEnd': eventEndTime.toString()
    });
    eventMark.remove(key);
    return null;
  }

  Future<void>? enableCrashReporter({
    required App app,
    required String apiKey,
    required String collectorUrl,
  }) async {
    try {
      final metadata = meta.toJson();
      metadata['app'] = app.toJson();
      metadata['apiKey'] = apiKey;
      metadata['collectorUrl'] = collectorUrl;
      if (Platform.isIOS) {
        _nativeChannel?.enableCrashReporter(metadata);
      }
      if (Platform.isAndroid) {
        final crashReports = await _nativeChannel?.getCrashReport();
        if (crashReports != null) {
          for (final crashInfo in crashReports) {
            final crashInfoJson = json.decode(crashInfo);
            final String reason = crashInfoJson['reason'];
            final int status = crashInfoJson['status'];
            // String description = crashInfoJson["description"];
            // description/stacktrace fails to send format and sanitize before push
            await _instance.pushError(
                type: 'crash', value: ' $reason , status: $status');
          }
        }
      }
    } catch (error, stacktrace) {
      log(
        'RumFlutter: enableCrashReporter failed with error: $error',
        stackTrace: stacktrace,
      );
    }
  }
}
