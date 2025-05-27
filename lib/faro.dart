// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:faro/faro_native_methods.dart';
import 'package:faro/faro_sdk.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/device_info/session_attributes_provider.dart';
import 'package:faro/src/models/span_record.dart';
import 'package:faro/src/tracing/tracer_provider.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/util/generate_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

Timer? timer;

typedef AppRunner = FutureOr<void> Function();

class Faro {
  factory Faro() {
    return _instance;
  }
  // Private constructor
  Faro._();

  // Singleton instance
  static Faro _instance = Faro._();

  @visibleForTesting
  static set instance(Faro instance) => _instance = instance;

  bool get enableDataCollection => DataCollectionPolicy().isEnabled;
  set enableDataCollection(bool enable) {
    if (enable) {
      DataCollectionPolicy().enable();
    } else {
      DataCollectionPolicy().disable();
    }
  }

  FaroConfig? config;
  List<BaseTransport> _transports = [];
  BatchTransport? _batchTransport;
  List<BaseTransport> get transports => _transports;

  Meta meta = Meta(
      session: Session(generateSessionID(), attributes: {}),
      sdk: Sdk('rum-flutter', '1.3.5', []),
      app: App(name: '', environment: '', version: ''),
      view: ViewMeta('default'));

  List<RegExp>? ignoreUrls = [];
  Map<String, dynamic> eventMark = {};
  FaroNativeMethods? _nativeChannel;

  FaroNativeMethods? get nativeChannel => _nativeChannel;

  @visibleForTesting
  set nativeChannel(FaroNativeMethods? nativeChannel) {
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

  Future<void> init({required FaroConfig optionsConfiguration}) async {
    final attributesProvider =
        await SessionAttributesProviderFactory().create();
    meta.session?.attributes = await attributesProvider.getAttributes();

    _nativeChannel ??= FaroNativeMethods();
    config = optionsConfiguration;
    _batchTransport = _batchTransport ??
        BatchTransport(
            payload: Payload(meta),
            batchConfig: config?.batchConfig ?? BatchConfig(),
            transports: _transports);

    if (config?.transports == null) {
      Faro()._transports.add(
            FaroTransport(
              collectorUrl: optionsConfiguration.collectorUrl ?? '',
              apiKey: optionsConfiguration.apiKey,
              maxBufferLimit: config?.maxBufferLimit,
              sessionId: meta.session?.id,
              headers: optionsConfiguration.collectorHeaders,
            ),
          );
    } else {
      Faro()._transports.addAll(config?.transports ?? []);
    }
    _instance.ignoreUrls = optionsConfiguration.ignoreUrls ?? [];
    final packageInfo = await PackageInfo.fromPlatform();
    _instance.setAppMeta(
      appName: optionsConfiguration.appName,
      appEnv: optionsConfiguration.appEnv,
      appVersion: optionsConfiguration.appVersion == null
          ? packageInfo.version
          : optionsConfiguration.appVersion!,
      namespace: optionsConfiguration.namespace ?? '',
    );
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
    WidgetsBinding.instance.addObserver(FaroWidgetsBindingObserver());
  }

  Future<void> runApp(
      {required FaroConfig optionsConfiguration,
      required AppRunner? appRunner}) async {
    OnErrorIntegration().call();
    FlutterErrorIntegration().call();
    await init(optionsConfiguration: optionsConfiguration);
    await appRunner!();
  }

  void setAppMeta({
    required String appName,
    required String appEnv,
    required String appVersion,
    required String? namespace,
  }) {
    final appMeta = App(
      name: appName,
      environment: appEnv,
      version: appVersion,
      namespace: namespace,
    );
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), 'app': appMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void setUserMeta({String? userId, String? userName, String? userEmail}) {
    final userMeta = User(id: userId, username: userName, email: userEmail);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), 'user': userMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);

    pushEvent('faro_internal_user_updated');
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
      FaroLog(message, level: level, context: context, trace: trace),
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
      parsedStackTrace = {'frames': FaroException.stackTraceParse(stacktrace)};
    }
    _batchTransport?.addExceptions(
      FaroException(type, value, parsedStackTrace, context: context),
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

            // Convert crashInfoJson from Map<String, dynamic> to Map<String, String>
            final stringifiedContext = <String, String>{};
            crashInfoJson.forEach((String key, dynamic value) {
              stringifiedContext[key] = value?.toString() ?? '';
            });

            final description =
                stringifiedContext['description'] ?? 'No description';
            final stacktrace =
                stringifiedContext['stacktrace'] ?? 'No stacktrace';
            final timestamp = stringifiedContext['timestamp'] ?? 'No timestamp';
            final importance =
                stringifiedContext['importance'] ?? 'No importance';
            final processName =
                stringifiedContext['processName'] ?? 'No processName';

            await _instance.pushError(
              type: 'crash',
              value: '$reason , status: $status',
              context: {
                'description': description,
                'stacktrace': stacktrace,
                'timestamp': timestamp,
                'importance': importance,
                'processName': processName,
              },
            );
          }
        }
      }
    } catch (error, stacktrace) {
      log(
        'Faro: enableCrashReporter failed with error: $error',
        stackTrace: stacktrace,
      );
    }
  }
}
