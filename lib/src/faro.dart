// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/device_info/session_attributes_provider.dart';
import 'package:faro/src/faro_widgets_binding_observer.dart';
import 'package:faro/src/integrations/flutter_error_integration.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/integrations/on_error_integration.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/user/user_manager.dart';
import 'package:faro/src/util/constants.dart';
import 'package:faro/src/util/timestamp_extension.dart';
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

  bool get enableDataCollection => _dataCollectionPolicy?.isEnabled ?? true;

  /// Set data collection enabled/disabled.
  /// This setting will be automatically persisted across app restarts.
  set enableDataCollection(bool enable) {
    if (enable) {
      _dataCollectionPolicy?.enable();
    } else {
      _dataCollectionPolicy?.disable();
    }
  }

  FaroConfig? config;
  List<BaseTransport> _transports = [];
  BatchTransport? _batchTransport;
  List<BaseTransport> get transports => _transports;
  DataCollectionPolicy? _dataCollectionPolicy;
  UserManager? _userManager;

  Meta meta = Meta(
      session: Session(
        SessionIdProviderFactory().create().sessionId,
        attributes: {},
      ),
      sdk: Sdk(FaroConstants.sdkName, '1.3.5', []),
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

  @visibleForTesting
  set dataCollectionPolicy(DataCollectionPolicy? policy) {
    _dataCollectionPolicy = policy;
  }

  @visibleForTesting
  set userManager(UserManager? manager) {
    _userManager = manager;
  }

  Future<void> init({required FaroConfig optionsConfiguration}) async {
    _dataCollectionPolicy = await DataCollectionPolicyFactory().create();

    final attributesProvider =
        await SessionAttributesProviderFactory().create();
    final customAttributes = optionsConfiguration.sessionAttributes ?? {};
    final defaultAttributes = await attributesProvider.getAttributes();
    // Merge custom attributes first, then default attributes
    // Default attributes take precedence if there are conflicts
    meta.session?.attributes = {...customAttributes, ...defaultAttributes};

    _nativeChannel ??= FaroNativeMethods();
    config = optionsConfiguration;

    // Initialize user manager (always with persistence to handle stale data cleanup)
    final userManager = await UserManagerFactory().create(
      onUserMetaApplied: _applyUserMeta,
      onPushEvent: pushEvent,
    );
    _userManager = userManager;

    await userManager.initialize(
      initialUser: optionsConfiguration.initialUser,
      persistUser: optionsConfiguration.persistUser,
    );

    _batchTransport = BatchTransportFactory().create(
      initialPayload: Payload(meta),
      batchConfig: config?.batchConfig ?? BatchConfig(),
      transports: _transports,
    );

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
    _instance.pushEvent('session_start');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NativeIntegration.instance.getAppStart();
    });
    WidgetsBinding.instance.addObserver(FaroWidgetsBindingObserver());
  }

  Future<void> runApp(
      {required FaroConfig optionsConfiguration,
      required AppRunner? appRunner}) async {
    if (optionsConfiguration.enableFlutterErrorReporting) {
      OnErrorIntegration().call();
      FlutterErrorIntegration().call();
    }
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

  /// Sets the user for all subsequent telemetry.
  ///
  /// The user information will be attached to all logs, events, exceptions,
  /// and traces sent to the Faro collector.
  ///
  /// If [persistUser] is enabled in [FaroConfig] (default: true), the user
  /// will be persisted and automatically restored on the next app start.
  ///
  /// To clear the user, pass [FaroUser.cleared].
  ///
  /// Returns a [Future] that completes when persistence is done. Callers can
  /// await this if they need to ensure persistence order, or ignore it for
  /// fire-and-forget behavior.
  ///
  /// Example:
  /// ```dart
  /// // Set user
  /// Faro().setUser(FaroUser(
  ///   id: 'user-123',
  ///   username: 'john.doe',
  ///   email: 'john@example.com',
  /// ));
  ///
  /// // Clear user
  /// Faro().setUser(FaroUser.cleared());
  /// ```
  Future<void> setUser(FaroUser user) async {
    await _userManager?.setUser(user, persistUser: config?.persistUser ?? true);
  }

  /// Sets the user metadata for all subsequent telemetry.
  ///
  /// This is a convenience method that creates a [FaroUser] internally.
  /// For more control, use [setUser] directly.
  ///
  /// If [persistUser] is enabled in [FaroConfig] (default: true), the user
  /// will be persisted and automatically restored on the next app start.
  ///
  /// If all parameters are null, the user will be cleared.
  @Deprecated('Use setUser(FaroUser(...)) instead. '
      'To clear, use setUser(FaroUser.cleared()).')
  void setUserMeta({String? userId, String? userName, String? userEmail}) {
    final user = (userId == null && userName == null && userEmail == null)
        ? const FaroUser.cleared()
        : FaroUser(id: userId, username: userName, email: userEmail);
    setUser(user);
  }

  /// Applies user JSON to meta.
  void _applyUserMeta(Map<String, dynamic> userJson) {
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), 'user': userJson});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void setViewMeta({String? name}) {
    final viewMeta = ViewMeta(name);
    _instance.meta =
        Meta.fromJson({..._instance.meta.toJson(), 'view': viewMeta.toJson()});
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void pushEvent(
    String name, {
    Map<String, dynamic>? attributes,
    Map<String, String>? trace,
  }) {
    _batchTransport?.addEvent(Event(
      name,
      attributes: attributes,
      trace: trace,
    ));
  }

  void pushLog(
    String message, {
    required LogLevel level,
    Map<String, dynamic>? context,
    Map<String, String>? trace,
  }) {
    _batchTransport?.addLog(
      FaroLog(message, level: level.value, context: context, trace: trace),
    );
  }

  void pushError({
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
  }

  void pushMeasurement(Map<String, dynamic>? values, String type) {
    _batchTransport?.addMeasurement(Measurement(values, type));
  }

  /// Starts an active span and executes the provided callback within its context.
  ///
  /// Active spans automatically manage their lifecycle - they start when the method
  /// is called and end when the callback completes (or throws an exception).
  /// This is the recommended way to create spans as it ensures proper cleanup.
  ///
  /// **Parent-Child Relationships:**
  /// If there's a currently active span when a new span is started, the new span
  /// will automatically become a child of the currently active span. However, if
  /// a [parentSpan] is explicitly provided, it will be used instead of the active
  /// span. This creates a hierarchical relationship where:
  /// - The outer span (or explicitly provided parent) becomes the parent
  /// - Any spans created inside the callback become children of this span
  /// - Errors are automatically associated with the appropriate span
  ///
  /// **Details:**
  /// Spans are collected with automatic parent-child relationships based on
  /// the execution context. This uses a zone-based implementation which ensures
  /// that spans created within the callback are properly associated with the
  /// correct parent span, even with asynchronous operations.
  ///
  /// **Parameters:**
  /// - [name]: The name of the span. This should be descriptive of the operation
  ///   being performed (e.g., "api_call", "database_query", "image_processing").
  /// - [body]: The callback function to execute within the span context. The
  ///   callback receives a [Span] object that can be used to add events,
  ///   attributes, or set the span status.
  /// - [attributes]: Optional key-value pairs to attach to the span. These are
  ///   useful for adding contextual information like user IDs, request IDs, etc.
  /// - [parentSpan]: Optional parent span to use instead of the currently active
  ///   span. When provided, this span will become the parent regardless of what
  ///   span is currently active. Useful for manual span hierarchy management.
  ///
  /// **Returns:**
  /// The result of the callback function. If the callback is synchronous, returns
  /// the value directly. If asynchronous, returns a Future that completes with
  /// the callback's result.
  ///
  /// **Error Handling:**
  /// If the callback throws an exception or returns a rejected Future, the span
  /// will be automatically marked as failed and the exception will be propagated.
  ///
  /// **Example - Synchronous operation:**
  /// ```dart
  /// final result = await Faro.startSpan('expensive_calculation', (span) {
  ///   span.setAttribute('input_size', '1000');
  ///   return performCalculation();
  /// });
  /// ```
  ///
  /// **Example - Asynchronous operation:**
  /// ```dart
  /// final data = await Faro.startSpan('api_request', (span) async {
  ///   span.setAttributes({
  ///     'url': 'https://api.example.com/users',
  ///     'method': 'GET',
  ///   });
  ///
  ///   try {
  ///     final response = await http.get(Uri.parse('https://api.example.com/users'));
  ///     span.setStatus(SpanStatusCode.ok);
  ///     return response.body;
  ///   } catch (e) {
  ///     span.setStatus(SpanStatusCode.error, message: e.toString());
  ///     span.addEvent('Request failed', attributes: {'error': e.toString()});
  ///     rethrow;
  ///   }
  /// });
  /// ```
  ///
  /// **Example - Nested spans:**
  /// ```dart
  /// final result = await Faro.startSpan('parent_operation', (parentSpan) async {
  ///   parentSpan.setAttribute('operation_id', '123');
  ///
  ///   final data = await fetchData();
  ///
  ///   return await Faro.startSpan('child_operation', (childSpan) async {
  ///     childSpan.setAttribute('data_size', data.length.toString());
  ///     return processData(data);
  ///   });
  /// });
  /// ```
  ///
  /// **Example - Manual parent span:**
  /// ```dart
  /// // Create a span manually to use as parent
  /// final rootSpan = Faro.startSpanManual('batch_operation');
  ///
  /// // Process multiple items with the same parent
  /// final futures = items.map((item) =>
  ///   Faro.startSpan('process_item', (span) async {
  ///     span.setAttribute('item_id', item.id);
  ///     return await processItem(item);
  ///   }, parentSpan: rootSpan)
  /// );
  ///
  /// final results = await Future.wait(futures);
  /// rootSpan.end(); // Don't forget to end the manual span
  /// ```
  ///
  /// **Note:** For most use cases, relying on automatic span hierarchy management
  /// (without specifying [parentSpan]) is recommended as it properly handles the
  /// execution context. Use the [parentSpan] parameter only when you need explicit
  /// control over span relationships. For scenarios requiring manual span lifecycle
  /// management, use [startSpanManual] instead, but remember to call [Span.end].
  ///
  /// See also:
  /// - [startSpanManual] for manual span lifecycle management
  /// - [Span] for available span operations
  /// - [SpanStatusCode] for available status codes
  FutureOr<T> startSpan<T>(
    String name,
    FutureOr<T> Function(Span) body, {
    Map<String, Object> attributes = const {},
    Span? parentSpan,
  }) async {
    return _tracer.startSpan(
      name,
      body,
      attributes: attributes,
      parentSpan: parentSpan,
    );
  }

  /// Starts an inactive span that requires manual lifecycle management.
  ///
  /// Unlike [startSpan], manual spans do not automatically end when a callback
  /// completes. You must explicitly call [Span.end] to properly close the span.
  /// This approach is useful when you need to span across multiple callback
  /// boundaries or when working with event-driven architectures.
  ///
  /// **Important:** Manual spans require explicit parent-child relationship management.
  /// While they can have children when specified via the [parentSpan] parameter,
  /// they don't automatically capture spans created in their execution context
  /// like active spans do. For automatic hierarchy management, prefer [startSpan].
  ///
  /// **Parameters:**
  /// - [name]: The name of the span. Should be descriptive of the operation.
  /// - [attributes]: Optional key-value pairs to attach to the span.
  /// - [parentSpan]: Optional parent span to use instead of the currently active
  ///   span. When provided, this span will become the parent regardless of what
  ///   span is currently active. Useful for creating custom span hierarchies.
  ///
  /// **Returns:**
  /// A [Span] object that you must manually manage. Remember to call [Span.end]
  /// when the operation completes.
  ///
  /// **Example - Basic manual span:**
  /// ```dart
  /// final span = Faro.startSpanManual('background_task',
  ///   attributes: {'task_id': '123'});
  ///
  /// try {
  ///   await performBackgroundWork();
  ///   span.setStatus(SpanStatusCode.ok);
  /// } catch (e) {
  ///   span.setStatus(SpanStatusCode.error, message: e.toString());
  ///   span.addEvent('Task failed', attributes: {'error': e.toString()});
  /// } finally {
  ///   span.end(); // Always remember to end the span
  /// }
  /// ```
  ///
  /// **Example - Manual hierarchy with custom parent:**
  /// ```dart
  /// final parentSpan = Faro.startSpanManual('request_batch');
  ///
  /// // Create multiple child spans with the same parent
  /// final span1 = Faro.startSpanManual('request_1', parentSpan: parentSpan);
  /// final span2 = Faro.startSpanManual('request_2', parentSpan: parentSpan);
  ///
  /// try {
  ///   // Perform operations...
  ///   span1.setStatus(SpanStatusCode.ok);
  ///   span2.setStatus(SpanStatusCode.ok);
  ///   parentSpan.setStatus(SpanStatusCode.ok);
  /// } finally {
  ///   // End all spans in reverse order (children first)
  ///   span1.end();
  ///   span2.end();
  ///   parentSpan.end();
  /// }
  /// ```
  ///
  /// See also:
  /// - [startSpan] for automatic span lifecycle management (recommended)
  /// - [Span.end] for closing manual spans
  /// - [Span] for available span operations
  Span startSpanManual(
    String name, {
    Map<String, Object> attributes = const {},
    Span? parentSpan,
  }) {
    return _tracer.startSpanManual(
      name,
      attributes: attributes,
      parentSpan: parentSpan,
    );
  }

  /// Returns the currently active span, if any.
  ///
  /// This method retrieves the span that is currently active in the execution
  /// context. Active spans are those created with [startSpan] and are automatically
  /// managed within their callback scope.
  ///
  /// **Returns:**
  /// The currently active [Span], or `null` if no span is currently active.
  ///
  /// **Use cases:**
  /// - Adding events or attributes to the current span from nested functions
  /// - Accessing span context for manual instrumentation
  ///
  /// **Example:**
  /// ```dart
  /// void logImportantEvent(String message) {
  ///   final activeSpan = Faro.getActiveSpan();
  ///   if (activeSpan != null) {
  ///     activeSpan.addEvent('important_event',
  ///       attributes: {'message': message});
  ///   }
  /// }
  ///
  /// // Usage within a span
  /// await Faro.startSpan('main_operation', (span) async {
  ///   await doSomeWork();
  ///   logImportantEvent('Work completed'); // Will add event to active span
  /// });
  /// ```
  ///
  /// **Note:** This method only returns spans created with [startSpan]. Manual
  /// spans created with [startSpanManual] are not considered "active" and won't
  /// be returned by this method.
  Span? getActiveSpan() {
    return _tracer.getActiveSpan();
  }

  void markEventStart(String key, String name) {
    final eventStartTime = DateTime.now().millisecondsSinceEpoch;
    eventMark[key] = {
      'eventName': name,
      'eventStartTime': eventStartTime,
    };
  }

  void markEventEnd(String key, String name,
      {Map<String, dynamic> attributes = const {}}) {
    final eventEndTime = DateTime.now().millisecondsSinceEpoch;
    if (name == 'http_request' && ignoreUrls != null) {
      if (ignoreUrls!
          .any((element) => element.stringMatch(attributes['url']) != null)) {
        return;
      }
    }
    if (!eventMark.containsKey(key)) {
      return;
    }
    final duration = eventEndTime - eventMark[key]['eventStartTime'];
    pushEvent(name, attributes: {
      ...attributes,
      'duration': duration.toString(),
      'eventStart': eventMark[key]['eventStartTime'].toString(),
      'eventEnd': eventEndTime.toString()
    });
    eventMark.remove(key);
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
            final humanReadableTimestamp = timestamp.toHumanReadableTimestamp();

            final importance =
                stringifiedContext['importance'] ?? 'No importance';
            final processName =
                stringifiedContext['processName'] ?? 'No processName';

            _instance.pushError(
              type: 'crash',
              value: '$reason , status: $status',
              context: {
                'description': description,
                'stacktrace': stacktrace,
                'timestamp': timestamp,
                'timestamp_readable_utc': humanReadableTimestamp,
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

  FaroTracer get _tracer => FaroTracerFactory().create();
}
