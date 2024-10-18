import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:rum_sdk/rum_native_methods.dart';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/data_collection_policy.dart';
import 'package:rum_sdk/src/models/session_attributes.dart';
import 'package:rum_sdk/src/transport/batch_transport.dart';
import 'package:rum_sdk/src/transport/rum_base_transport.dart';
import 'package:rum_sdk/src/util/generate_session.dart';

Timer? timer;

typedef AppRunner = FutureOr<void> Function();

class RumFlutter {
  // Private constructor
  RumFlutter._();

  // Singleton instance
  static RumFlutter _instance = RumFlutter._();

  factory RumFlutter() {
    return _instance;
  }

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
      sdk: Sdk("rum-flutter", "1.3.5", []),
      app: App("", "", ""),
      view: ViewMeta("default"));

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
    meta.session?.attributes = await SessionAttributes().getAttributes();

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
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
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
        collectorUrl: optionsConfiguration.collectorUrl ?? "",
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
    await _instance.pushEvent("session_start");
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
    App appMeta = App(appName, appEnv, appVersion);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), "app": appMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void setUserMeta({String? userId, String? userName, String? userEmail}) {
    User userMeta = User(id: userId, username: userName, email: userEmail);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), "user": userMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void setViewMeta({String? name}) {
    ViewMeta viewMeta = ViewMeta(name);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), "view": viewMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  Future<void>? pushEvent(String name, {Map<String, String?>? attributes}) {
    _batchTransport?.addEvent(Event(name, attributes: attributes));
    return null;
  }

  Future<void>? pushLog(String message,
      {String? level,
      Map<String, dynamic>? context,
      Map<String, dynamic>? trace}) {
    _batchTransport?.addLog(
      RumLog(message, level: level, context: context, trace: trace),
    );
    return null;
  }

  Future<void>? pushError(
      {required type,
      required value,
      StackTrace? stacktrace,
      Map<String, String>? context}) {
    Map<String, dynamic> parsedStackTrace = {};
    if (stacktrace != null) {
      parsedStackTrace = {"frames": RumException.stackTraceParse(stacktrace)};
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

  void markEventStart(String key, String name) {
    var eventStartTime = DateTime.now().millisecondsSinceEpoch;
    eventMark[key] = {
      "eventName": name,
      "eventStartTime": eventStartTime,
    };
  }

  Future<void>? markEventEnd(String key, String name,
      {Map<String, dynamic> attributes = const {}}) {
    var eventEndTime = DateTime.now().millisecondsSinceEpoch;
    if (name == "http_request" && ignoreUrls != null) {
      if (ignoreUrls!
          .any((element) => element.stringMatch(attributes["url"]) != null)) {
        return null;
      }
    }
    if (!eventMark.containsKey(key)) {
      return null;
    }
    var duration = eventEndTime - eventMark[key]["eventStartTime"];
    pushEvent(name, attributes: {
      ...attributes,
      "duration": duration.toString(),
      "eventStart": eventMark[key]["eventStartTime"].toString(),
      "eventEnd": eventEndTime.toString()
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
      Map<String, dynamic> metadata = meta.toJson();
      metadata["app"] = app.toJson();
      metadata["apiKey"] = apiKey;
      metadata["collectorUrl"] = collectorUrl;
      if (Platform.isIOS) {
        _nativeChannel?.enableCrashReporter(metadata);
      }
      if (Platform.isAndroid) {
        List<String>? crashReports = await _nativeChannel?.getCrashReport();
        if (crashReports != null) {
          for (var crashInfo in crashReports) {
            final crashInfoJson = json.decode(crashInfo);
            String reason = crashInfoJson["reason"];
            int status = crashInfoJson["status"];
            // String description = crashInfoJson["description"];
            // description/stacktrace fails to send format and sanitize before push
            await _instance.pushError(
                type: "crash", value: " $reason , status: $status");
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
