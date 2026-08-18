// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/device_info/session_attributes_provider.dart';
import 'package:faro/src/faro_widgets_binding_observer.dart';
import 'package:faro/src/integrations/flutter_error_integration.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/integrations/on_error_integration.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_id_provider.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/session/session_persistence.dart';
import 'package:faro/src/session/session_runtime_info.dart';
import 'package:faro/src/session/session_sampling_provider.dart';
import 'package:faro/src/tracing/faro_otel_bootstrap.dart';
import 'package:faro/src/tracing/faro_span_context.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/tracing/span_exception_options.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:faro/src/user/user_manager.dart';
import 'package:faro/src/user_actions/start_user_action_options.dart';
import 'package:faro/src/user_actions/telemetry_router.dart';
import 'package:faro/src/user_actions/user_action_handle.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/user_actions/user_action_ui_activity_monitor.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';
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

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _instance._tearDownForReset();
    await FaroOtelBootstrap.resetForTesting();
    _instance = Faro._();
  }

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
  SessionPersistence? _sessionPersistence;
  SessionPersistenceFactory _sessionPersistenceFactory =
      SessionPersistenceFactory();
  bool Function() _isMobilePlatform = () =>
      Platform.isAndroid || Platform.isIOS;
  bool Function() _isAndroidPlatform = () => Platform.isAndroid;
  bool Function() _isIOSPlatform = () => Platform.isIOS;
  List<PersistedSessionRecord> _recoveredSessionHistory =
      const <PersistedSessionRecord>[];
  String? _sessionProcessIdentifier;
  bool _ownsSessionPersistence = false;
  bool _isSampled = true;
  bool _isInitialized = false;
  FaroWidgetsBindingObserver? _widgetsBindingObserver;
  bool _didAttachUiActivityMonitor = false;

  /// Whether the current session is sampled.
  ///
  /// When `true`, telemetry data is being collected for this session.
  /// When `false`, telemetry data is being dropped.
  bool get isSampled => _isSampled;

  Meta meta = Meta(
    session: Session(_sessionIdProvider.sessionId, attributes: {}),
    sdk: Sdk(FaroConstants.sdkName, FaroConstants.sdkVersion),
    app: App(name: '', environment: '', version: ''),
    view: ViewMeta('default'),
  );

  HttpTrackingFilter get _httpTrackingFilter =>
      pod.resolve(httpTrackingFilterProvider);
  Map<String, dynamic> eventMark = {};
  FaroNativeMethods? _nativeChannel;

  FaroNativeMethods? get nativeChannel => _nativeChannel;

  static SessionIdProvider get _sessionIdProvider =>
      pod.resolve(sessionIdProviderProvider);

  TelemetryRouter get _telemetryRouter => pod.resolve(telemetryRouterProvider);

  NativeIntegration get _nativeIntegration =>
      pod.resolve(nativeIntegrationProvider);

  UserActionsService get _userActionsService =>
      pod.resolve(userActionsServiceProvider);

  UserActionUiActivityMonitor get _userActionUiActivityMonitor =>
      pod.resolve(userActionUiActivityMonitorProvider);

  FaroTracer get _tracer => pod.resolve(faroTracerProvider);

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
    pod.overrideProvider(batchTransportProvider, (_) => batchTransport);
  }

  @visibleForTesting
  set dataCollectionPolicy(DataCollectionPolicy? policy) {
    _dataCollectionPolicy = policy;
  }

  @visibleForTesting
  set userManager(UserManager? manager) {
    _userManager = manager;
  }

  @visibleForTesting
  set sessionPersistenceFactory(SessionPersistenceFactory factory) {
    _sessionPersistenceFactory = factory;
  }

  @visibleForTesting
  set mobilePlatformResolver(bool Function() resolver) {
    _isMobilePlatform = resolver;
  }

  @visibleForTesting
  set androidPlatformResolver(bool Function() resolver) {
    _isAndroidPlatform = resolver;
  }

  @visibleForTesting
  set iosPlatformResolver(bool Function() resolver) {
    _isIOSPlatform = resolver;
  }

  Future<void> init({required FaroConfig optionsConfiguration}) async {
    if (_isInitialized) {
      log('Faro: init() called after initialization; ignoring.');
      return;
    }

    _dataCollectionPolicy = await DataCollectionPolicyFactory().create();

    final attributesProvider = await SessionAttributesProviderFactory()
        .create();
    final customAttributes = optionsConfiguration.sessionAttributes ?? {};
    final collectedAttributes = await attributesProvider.collectAttributes();
    final installationId = collectedAttributes.installationId;
    final deviceInfo = collectedAttributes.deviceInfo;
    final defaultAttributes = collectedAttributes.attributes;
    // Merge custom attributes first, then default attributes
    // Default attributes take precedence if there are conflicts
    meta.session?.attributes = {...customAttributes, ...defaultAttributes};
    _setDeviceAndOsMeta(deviceInfo);

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

    // Set app meta before sampling so sampler has access to full context
    final appVersion = await _resolveAppVersion(
      optionsConfiguration.appVersion,
    );
    setAppMeta(
      appName: optionsConfiguration.appName,
      appEnv: optionsConfiguration.appEnv,
      appVersion: appVersion,
      namespace: optionsConfiguration.namespace ?? '',
      installationId: '$installationId',
    );

    final persistedPreviousSession = await _initializeSessionPersistence(
      optionsConfiguration,
    );

    // Make sampling decision (once per session)
    _isSampled = SessionSamplingProviderFactory()
        .create(sampling: optionsConfiguration.sampling, meta: meta)
        .isSampled;

    if (!_isSampled) {
      log('Faro: Session not sampled. Telemetry will be dropped.');
    }

    final batchTransport = BatchTransportFactory().create(
      initialPayload: Payload(meta),
      batchConfig: config?.batchConfig ?? BatchConfig(),
      transports: _transports,
      isSampled: _isSampled,
    );
    _batchTransport = batchTransport;
    pod.overrideProvider(batchTransportProvider, (_) => batchTransport);

    final sessionManager = pod.resolve(sessionManagerProvider)
      ..addListener(_onSessionChanged)
      ..addStateListener(_onSessionStateChanged);

    if (config?.transports == null) {
      Faro()._transports.add(
        FaroTransport(
          collectorUrl: optionsConfiguration.collectorUrl ?? '',
          apiKey: optionsConfiguration.apiKey,
          maxBufferLimit: config?.maxBufferLimit,
          sessionIdResolver: () => _sessionIdProvider.sessionId,
          headers: optionsConfiguration.collectorHeaders,
        ),
      );
    } else {
      Faro()._transports.addAll(config?.transports ?? []);
    }
    for (final transport in _transports.whereType<FaroTransport>()) {
      transport.sessionInvalidatedHandler = sessionManager.invalidateSession;
    }
    _httpTrackingFilter.configure(
      collectorUrl: optionsConfiguration.collectorUrl,
      ignoreUrls: optionsConfiguration.ignoreUrls,
    );
    if (config?.enableCrashReporting == true) {
      _instance.enableCrashReporter(
        app: _instance.meta.app!,
        apiKey: optionsConfiguration.apiKey,
        collectorUrl: optionsConfiguration.collectorUrl ?? '',
        recoveredSession: persistedPreviousSession,
      );
    }
    if (Platform.isAndroid || Platform.isIOS) {
      _nativeIntegration.init(
        memusage: optionsConfiguration.memoryUsageVitals,
        cpuusage: optionsConfiguration.cpuUsageVitals,
        anr: optionsConfiguration.anrTracking,
        refreshrate: optionsConfiguration.refreshRateVitals,
        setSendUsageInterval: optionsConfiguration.fetchVitalsInterval,
      );
    }
    await FaroOtelBootstrap.initialize();
    // Announce the initial session; the listener emits `session_start`.
    sessionManager.start(
      previousSessionId: persistedPreviousSession?.currentSessionId,
    );
    await _sessionPersistence?.flush();
    _reportColdStartAfterFirstFrame();

    _widgetsBindingObserver = FaroWidgetsBindingObserver(
      nativeIntegration: _nativeIntegration,
      sessionManager: sessionManager,
      onAppBackgrounded: _flushSessionPersistence,
    );
    WidgetsBinding.instance.addObserver(_widgetsBindingObserver!);
    if (optionsConfiguration.enableUiActivityMonitoring) {
      _userActionUiActivityMonitor.attach();
      _didAttachUiActivityMonitor = true;
    }
    _isInitialized = true;
  }

  Future<void> runApp({
    required FaroConfig optionsConfiguration,
    required AppRunner? appRunner,
  }) async {
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
    String? installationId,
  }) {
    final appMeta = App(
      name: appName,
      environment: appEnv,
      version: appVersion,
      namespace: namespace,
      installationId: installationId ?? _instance.meta.app?.installationId,
    );
    _instance.meta = Meta.fromJson({
      ..._instance.meta.toJson(),
      'app': appMeta.toJson(),
    });
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void _setDeviceAndOsMeta(DeviceInfo deviceInfo) {
    _instance.meta = Meta.fromJson({
      ..._instance.meta.toJson(),
      'device': Device(
        manufacturer: deviceInfo.deviceManufacturer,
        modelIdentifier: deviceInfo.deviceModel,
        modelName: deviceInfo.deviceModelName,
        brand: deviceInfo.deviceBrand,
        isPhysical: deviceInfo.deviceIsPhysical,
        type: deviceInfo.deviceType,
      ).toJson(),
      'os': Os(
        name: deviceInfo.deviceOs,
        version: deviceInfo.deviceOsVersion,
        buildId: deviceInfo.deviceOsBuildId,
        detail: deviceInfo.deviceOsDetail,
      ).toJson(),
    });
  }

  void _onSessionChanged({
    required String currentId,
    String? previousId,
    required SessionStartTrigger trigger,
  }) {
    final attributes = <String, dynamic>{...?meta.session?.attributes};
    if (previousId != null) {
      attributes['previousSession'] = previousId;
    }

    meta = Meta.fromJson({
      ...meta.toJson(),
      'session': Session(currentId, attributes: attributes).toJson(),
    });
    _batchTransport?.updatePayloadMeta(meta);

    if (trigger == SessionStartTrigger.explicitReset) {
      _restartSamplingForNewSession();
    }

    // Lifecycle events bypass user-action buffering and never count as
    // session activity (SDK-emitted, not app/user behavior).
    _telemetryRouter.ingest(
      TelemetryItem.fromEvent(Event('session_start')),
      skipBuffer: true,
      activity: SessionActivityKind.passive,
    );
  }

  void _onSessionStateChanged(
    SessionState state,
    SessionStateChangeKind changeKind,
  ) {
    _sessionPersistence?.record(
      state,
      isSampled: _isSampled,
      immediate: changeKind == SessionStateChangeKind.sessionStarted,
    );
  }

  Future<PersistedSessionRecord?> _initializeSessionPersistence(
    FaroConfig options,
  ) async {
    if (!_isMobilePlatform()) {
      return null;
    }

    final nativeChannel = _nativeChannel;
    if (nativeChannel == null) {
      return null;
    }

    final runtimeInfo = await SessionRuntimeInfoProvider(
      nativeMethods: nativeChannel,
      engineRole: options.engineRole,
    ).getRuntimeInfo();
    if (runtimeInfo == null) {
      return null;
    }
    _sessionProcessIdentifier = runtimeInfo.processIdentifier;
    _ownsSessionPersistence = runtimeInfo.ownsSessionPersistence;

    final session = meta.session;
    if (session != null) {
      session.attributes = <String, dynamic>{
        ...?session.attributes,
        'process_name': runtimeInfo.processIdentifier,
        'dart_isolate_name': runtimeInfo.isolateIdentifier,
      };
    }

    if (!runtimeInfo.ownsSessionPersistence) {
      return null;
    }

    try {
      final persistence = await _sessionPersistenceFactory.create(
        processIdentifier: runtimeInfo.processIdentifier,
      );
      if (!options.persistSession) {
        await persistence.clear();
        return null;
      }

      _sessionPersistence = persistence;
      _recoveredSessionHistory = await persistence.loadHistory();
      return _recoveredSessionHistory.isEmpty
          ? null
          : _recoveredSessionHistory.last;
    } catch (error) {
      log('Faro: Session persistence unavailable: $error');
      _sessionPersistence = null;
      return null;
    }
  }

  Future<void> _flushSessionPersistence() async {
    await _sessionPersistence?.flush();
  }

  void _restartSamplingForNewSession() {
    final previousDecision = _isSampled;
    _isSampled = SessionSamplingProviderFactory()
        .createForNewSession(sampling: config?.sampling, meta: meta)
        .isSampled;

    if (_isSampled == previousDecision) {
      return;
    }

    final batchTransport = BatchTransportFactory().replace(
      initialPayload: Payload(meta),
      batchConfig: config?.batchConfig ?? BatchConfig(),
      transports: _transports,
      isSampled: _isSampled,
    );
    _batchTransport = batchTransport;
    pod.overrideProvider(batchTransportProvider, (_) => batchTransport);

    if (!_isSampled) {
      log('Faro: Session not sampled. Telemetry will be dropped.');
    }
  }

  /// Ends the cold start interval at the first frame the engine rasterized.
  ///
  /// Using that frame rather than the next one after `init` limits how far the
  /// measurement stretches when a host app initialises Faro late. It cannot
  /// remove the stretch: the native side measures up to the moment it is
  /// called, so an app that initialises Faro after the first frame is measured
  /// to `init`, the future having already completed.
  void _reportColdStartAfterFirstFrame() {
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
        (_) => _nativeIntegration.getAppStart(),
      ),
    );
  }

  Future<void> _tearDownForReset() async {
    await _sessionPersistence?.flush();
    _sessionPersistence = null;
    _ownsSessionPersistence = false;
    final widgetsBindingObserver = _widgetsBindingObserver;
    if (widgetsBindingObserver != null) {
      WidgetsBinding.instance.removeObserver(widgetsBindingObserver);
      _widgetsBindingObserver = null;
    }
    _widgetsBindingObserver = null;
    if (_didAttachUiActivityMonitor) {
      _userActionUiActivityMonitor.detach();
      _didAttachUiActivityMonitor = false;
    }
    // Evict per-init session state so the next init resolves fresh instances.
    // Disposable instances (e.g. NativeIntegration's vitals timer) are also
    // cleaned up here.
    pod.clearScope(faroInitScope);
    _isInitialized = false;
  }

  /// Starts a new session for logout, account changes, or a custom boundary.
  ///
  /// The new session is created immediately and links the previous session ID.
  /// Its lifetime, inactivity, and sampling windows start over, and Faro emits
  /// the normal `session_start` event. When session persistence is enabled, the
  /// returned future completes after the new record has been written.
  /// Any active user action is ended first so its buffered telemetry remains in
  /// the previous session.
  ///
  /// Calls made before [init] are ignored.
  ///
  /// Example:
  /// ```dart
  /// await Faro().setUser(const FaroUser.cleared());
  /// await Faro().resetSession();
  /// ```
  Future<void> resetSession() async {
    if (!_isInitialized) {
      log('Faro: resetSession() called before initialization; ignoring.');
      return;
    }

    _userActionsService.endActiveUserAction();
    pod.resolve(sessionManagerProvider).resetSession();
    await _sessionPersistence?.flush();
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
  @Deprecated(
    'Use setUser(FaroUser(...)) instead. '
    'To clear, use setUser(FaroUser.cleared()).',
  )
  void setUserMeta({String? userId, String? userName, String? userEmail}) {
    final user = (userId == null && userName == null && userEmail == null)
        ? const FaroUser.cleared()
        : FaroUser(id: userId, username: userName, email: userEmail);
    setUser(user);
  }

  /// Resolves the app version from config or platform.
  ///
  /// Uses the provided [configuredVersion] if available, otherwise fetches
  /// from [PackageInfo]. Falls back to 'unknown' if PackageInfo fails
  /// (e.g., in background isolates or before runApp()).
  Future<String> _resolveAppVersion(String? configuredVersion) async {
    if (configuredVersion != null) {
      return configuredVersion;
    }
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (e) {
      log('Faro: Failed to get app version from PackageInfo: $e');
      return 'unknown';
    }
  }

  /// Applies user JSON to meta.
  void _applyUserMeta(Map<String, dynamic> userJson) {
    _instance.meta = Meta.fromJson({
      ..._instance.meta.toJson(),
      'user': userJson,
    });
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void setViewMeta({String? name}) {
    if ((_instance.meta.view?.name ?? '') == (name ?? '')) {
      return;
    }
    pod
        .resolve(sessionManagerProvider)
        .checkSession(activity: SessionActivityKind.meaningful);
    final viewMeta = ViewMeta(name);
    _instance.meta = Meta.fromJson({
      ..._instance.meta.toJson(),
      'view': viewMeta.toJson(),
    });
    _instance._batchTransport?.updatePayloadMeta(_instance.meta);
  }

  void pushEvent(
    String name, {
    Map<String, dynamic>? attributes,
    FaroSpanContext? spanContext,
  }) {
    final event = Event(
      name,
      attributes: attributes,
      trace: (spanContext ?? _tracer.getActiveSpanContext())?.toJson(),
    );
    _telemetryRouter.ingest(
      TelemetryItem.fromEvent(event),
      activity: SessionActivityKind.passive,
    );
  }

  void pushLog(
    String message, {
    required LogLevel level,
    Map<String, dynamic>? context,
    FaroSpanContext? spanContext,
  }) {
    final faroLog = FaroLog(
      message,
      level: level.value,
      context: context,
      trace: (spanContext ?? _tracer.getActiveSpanContext())?.toJson(),
    );
    _telemetryRouter.ingest(
      TelemetryItem.fromLog(faroLog),
      activity: SessionActivityKind.passive,
    );
  }

  void pushError({
    required String type,
    required String value,
    StackTrace? stacktrace,
    Map<String, String>? context,
    FaroSpanContext? spanContext,
    bool fatal = false,
  }) {
    var parsedStackTrace = <String, dynamic>{};
    if (stacktrace != null) {
      parsedStackTrace = {'frames': FaroException.stackTraceParse(stacktrace)};
    }

    final faroException = FaroException(
      type,
      value,
      parsedStackTrace,
      context: context,
      trace: (spanContext ?? _tracer.getActiveSpanContext())?.toJson(),
      fatal: fatal,
    );
    _telemetryRouter.ingest(
      TelemetryItem.fromException(faroException),
      activity: SessionActivityKind.passive,
    );
  }

  void pushMeasurement(
    Map<String, dynamic>? values,
    String type, {
    FaroSpanContext? spanContext,
  }) {
    _telemetryRouter.ingest(
      TelemetryItem.fromMeasurement(
        Measurement(
          values,
          type,
          trace: (spanContext ?? _tracer.getActiveSpanContext())?.toJson(),
        ),
      ),
      activity: SessionActivityKind.passive,
    );
  }

  /// Starts an active span and executes the provided callback within its context.
  ///
  /// Active spans automatically manage their lifecycle - they start when called
  /// and end when the callback completes. This is the recommended way to create
  /// spans. Nested spans automatically become children of the currently active
  /// span, creating a hierarchical trace structure.
  ///
  /// **Parameters:**
  /// - [name]: Descriptive name for the operation (e.g., "api_call", "db_query").
  /// - [body]: Callback to execute. Receives a [Span] for adding events/attributes.
  /// - [attributes]: Optional key-value pairs to attach to the span.
  /// - [parentSpan]: Controls parent relationship:
  ///   - `null` (default): Uses active span from context.
  ///   - [Span.noParent]: Starts a new root trace with no parent.
  ///   - Specific [Span]: Uses that span as parent.
  /// - [contextScope]: Controls how long the span stays active as a parent:
  ///   - [ContextScope.callback] (default): Deactivated when callback completes.
  ///   - [ContextScope.zone]: Stays active for timers/streams in the zone.
  ///   See [ContextScope] for detailed examples.
  /// - [exceptionOptions]: Controls how exceptions are recorded on the span.
  ///   Merged with global [FaroConfig.spanExceptionOptions]. Only explicitly
  ///   set fields override the global values; omitted fields inherit from
  ///   global config.
  ///   See [SpanExceptionOptions] for details.
  ///
  /// **Example - Basic usage:**
  /// ```dart
  /// final data = await Faro().startSpan('api_request', (span) async {
  ///   span.setAttribute('url', 'https://api.example.com/users');
  ///   final response = await http.get(Uri.parse('https://api.example.com/users'));
  ///   return response.body;
  /// });
  /// ```
  ///
  /// **Example - Nested spans:**
  /// ```dart
  /// await Faro().startSpan('parent_operation', (parent) async {
  ///   final data = await fetchData();
  ///   return await Faro().startSpan('child_operation', (child) async {
  ///     return processData(data);
  ///   });
  /// });
  /// ```
  ///
  /// **Example - Explicit parent with batch processing:**
  /// ```dart
  /// final rootSpan = Faro().startSpanManual('batch_operation');
  /// final futures = items.map((item) =>
  ///   Faro().startSpan('process_item', parentSpan: rootSpan, (span) async {
  ///     return await processItem(item);
  ///   })
  /// );
  /// await Future.wait(futures);
  /// rootSpan.end();
  /// ```
  ///
  /// **Example - Custom exception sanitization:**
  /// ```dart
  /// await Faro().startSpan(
  ///   'payment',
  ///   (span) async {
  ///     span.setAttribute('payment.id', paymentId);
  ///     await processPayment();
  ///   },
  ///   exceptionOptions: SpanExceptionOptions(
  ///     exceptionSanitizer: (error, stackTrace) {
  ///       return SanitizedSpanException(
  ///         type: error.runtimeType.toString(),
  ///         message: 'Payment failed',
  ///         statusDescription: 'Payment processing error',
  ///       );
  ///     },
  ///   ),
  /// );
  /// ```
  ///
  /// See also:
  /// - [startSpanManual] for manual span lifecycle management
  /// - [ContextScope] for timer/stream context behavior
  /// - [Span.noParent] for starting independent traces
  FutureOr<T> startSpan<T>(
    String name,
    FutureOr<T> Function(Span) body, {
    Map<String, Object> attributes = const {},
    Span? parentSpan,
    ContextScope contextScope = ContextScope.callback,
    SpanExceptionOptions? exceptionOptions,
  }) async {
    final effectiveOptions =
        (config?.spanExceptionOptions ?? SpanExceptionOptions.defaults)
            .mergeWith(exceptionOptions);
    return _tracer.startSpan(
      name,
      body,
      attributes: attributes,
      parentSpan: parentSpan,
      contextScope: contextScope,
      exceptionOptions: effectiveOptions,
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
  /// - [parentSpan]: Controls the parent span relationship with three states:
  ///   - **Not provided / null**: Uses the active span from zone context
  ///     (default behavior).
  ///   - **[Span.noParent]**: Explicitly starts a new root trace with no parent,
  ///     ignoring any active span in the context.
  ///   - **Specific [Span] instance**: Uses that span as the parent.
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

  /// Starts a new user action to track user interactions.
  ///
  /// User actions automatically capture and correlate all telemetry (logs, events,
  /// exceptions) that occurs during the action's lifetime. When the action ends,
  /// all captured telemetry is enriched with action context.
  ///
  /// Only one user action can be active at a time. If a user action is already
  /// running, this method returns `null`.
  ///
  /// **Parameters:**
  /// - [name]: Human-readable name for the action (e.g., "checkout-button", "login-flow")
  /// - [attributes]: Optional custom attributes to attach to the action
  /// - [options]: Optional start options, such as [StartUserActionOptions.triggerName]
  ///   and [StartUserActionOptions.importance]
  ///
  /// **Returns:**
  /// A [UserActionHandle] if started successfully, or `null` if another action
  /// is already active or Faro has not been initialized.
  ///
  /// **Example:**
  /// ```dart
  /// final action = Faro().startUserAction(
  ///   'checkout-flow',
  ///   attributes: {'product': 'premium', 'price': '99.99'},
  ///   options: StartUserActionOptions(
  ///     importance: 'critical',
  ///   ),
  /// );
  ///
  /// if (action != null) {
  ///   // Perform operations - all telemetry automatically associated
  ///   await processCheckout();
  ///   // Action ends automatically via controller
  /// }
  /// ```
  ///
  /// **Note:** The action lifecycle is managed automatically by internal
  /// user-action services.
  UserActionHandle? startUserAction(
    String name, {
    Map<String, String>? attributes,
    StartUserActionOptions? options,
  }) {
    final action = _userActionsService.startUserAction(
      name,
      attributes: attributes,
      options: options,
    );
    if (action != null) {
      pod
          .resolve(sessionManagerProvider)
          .checkSession(activity: SessionActivityKind.meaningful);
    }
    return action;
  }

  /// Returns the currently active user action, if any.
  ///
  /// This can be used to check if a user action is running or to access
  /// the action's properties (name, ID, state, etc.).
  ///
  /// **Returns:**
  /// The active [UserActionHandle], or `null` if no action is currently running.
  ///
  /// **Example:**
  /// ```dart
  /// final action = Faro().getActiveUserAction();
  /// if (action != null) {
  ///   print('Active action: ${action.name} (${action.getState()})');
  /// }
  /// ```
  UserActionHandle? getActiveUserAction() =>
      _userActionsService.getActiveUserAction();

  /// Deprecated: use [startSpan] for duration tracking, or
  /// [startUserAction] for interaction-level correlation.
  ///
  /// Example migration:
  /// ```dart
  /// await Faro().startSpan('operation_name', (span) async {
  ///   await doWork();
  /// });
  /// ```
  @Deprecated('Use startSpan() for duration tracking.')
  void markEventStart(String key, String name) {
    final eventStartTime = DateTime.now().millisecondsSinceEpoch;
    eventMark[key] = {'eventName': name, 'eventStartTime': eventStartTime};
  }

  /// Deprecated: use [startSpan] for duration tracking, or
  /// [startUserAction] for interaction-level correlation.
  ///
  /// Example migration:
  /// ```dart
  /// await Faro().startSpan('operation_name', (span) async {
  ///   await doWork();
  /// });
  /// ```
  @Deprecated('Use startSpan() for duration tracking.')
  void markEventEnd(
    String key,
    String name, {
    Map<String, dynamic> attributes = const {},
  }) {
    final eventEndTime = DateTime.now().millisecondsSinceEpoch;
    if (!eventMark.containsKey(key)) {
      return;
    }
    final duration = eventEndTime - eventMark[key]['eventStartTime'];
    pushEvent(
      name,
      attributes: {
        ...attributes,
        'duration': duration.toString(),
        'eventStart': eventMark[key]['eventStartTime'].toString(),
        'eventEnd': eventEndTime.toString(),
      },
    );
    eventMark.remove(key);
  }

  Future<void>? enableCrashReporter({
    required App app,
    required String apiKey,
    required String collectorUrl,
    PersistedSessionRecord? recoveredSession,
  }) async {
    try {
      if (_isIOSPlatform()) {
        await _nativeChannel?.enableCrashReporter(const <String, dynamic>{});
        if (_ownsSessionPersistence) {
          final crashReports = await _nativeChannel?.getCrashReport();
          if (crashReports != null) {
            final recoveredSessions = _sessionPersistence != null
                ? _recoveredSessionHistory
                : null;
            // Recovery sends must not hold up the next app launch.
            unawaited(
              _reportIOSCrashReports(
                crashReports,
                recoveredSessions: recoveredSessions,
              ),
            );
          }
        }
      }
      if (_isAndroidPlatform()) {
        final crashReports = await _nativeChannel?.getCrashReport();
        if (crashReports != null) {
          final recoveredSessions = _sessionPersistence != null
              ? _recoveredSessionHistory
              : recoveredSession == null
              ? null
              : <PersistedSessionRecord>[recoveredSession];
          // Recovery sends must not hold up the next app launch.
          unawaited(
            _reportAndroidCrashReports(
              crashReports,
              recoveredSessions: recoveredSessions,
              processIdentifier: _sessionPersistence == null
                  ? null
                  : _sessionProcessIdentifier,
            ),
          );
        }
      }
    } catch (error, stacktrace) {
      log(
        'Faro: enableCrashReporter failed with error: $error',
        stackTrace: stacktrace,
      );
    }
  }

  @visibleForTesting
  Future<void> reportIOSCrashesForTesting(
    List<String> crashReports, {
    PersistedSessionRecord? recoveredSession,
    List<PersistedSessionRecord>? recoveredSessions,
  }) {
    return _reportIOSCrashReports(
      crashReports,
      recoveredSessions:
          recoveredSessions ??
          (recoveredSession == null
              ? null
              : <PersistedSessionRecord>[recoveredSession]),
    );
  }

  @visibleForTesting
  Future<void> reportAndroidCrashesForTesting(
    List<String> crashReports, {
    PersistedSessionRecord? recoveredSession,
    List<PersistedSessionRecord>? recoveredSessions,
    String? processIdentifier,
  }) {
    return _reportAndroidCrashReports(
      crashReports,
      recoveredSessions:
          recoveredSessions ??
          (recoveredSession == null
              ? null
              : <PersistedSessionRecord>[recoveredSession]),
      processIdentifier: processIdentifier,
    );
  }

  Meta _metaForRecoveredSession(PersistedSessionRecord recoveredSession) {
    final attributes = <String, dynamic>{
      'crashedSessionId': recoveredSession.currentSessionId,
      'isSampled': recoveredSession.isSampled,
    };
    final previousSessionId = recoveredSession.previousSessionId;
    if (previousSessionId != null) {
      attributes['previousSession'] = previousSessionId;
    }

    return Meta(
      session: Session(
        recoveredSession.currentSessionId,
        attributes: attributes,
      ),
      sdk: meta.sdk,
      app: meta.app,
      device: meta.device,
      os: meta.os,
    );
  }

  Future<void> _reportAndroidCrashReports(
    List<String> crashReports, {
    required List<PersistedSessionRecord>? recoveredSessions,
    required String? processIdentifier,
  }) async {
    for (final crashInfo in crashReports) {
      late final FaroException exception;
      PersistedSessionRecord? recoveredSession;
      try {
        final decoded = json.decode(crashInfo);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Crash report must be an object');
        }

        if (recoveredSessions != null) {
          recoveredSession = _matchRecoveredSession(
            decoded,
            recoveredSessions,
            processIdentifier: processIdentifier,
          );
          if (recoveredSession == null) {
            log('Faro: Ignoring Android crash without a matching session');
            continue;
          }
        }

        exception = _androidCrashException(
          decoded,
          crashedSessionId: recoveredSession?.currentSessionId,
        );
      } catch (error, stacktrace) {
        log(
          'Faro: Ignoring malformed Android crash report: $error',
          stackTrace: stacktrace,
        );
        continue;
      }

      try {
        if (recoveredSession == null) {
          _instance.pushError(
            type: exception.type,
            value: exception.value,
            fatal: exception.fatal,
            context: exception.context,
          );
        } else if (recoveredSession.isSampled) {
          await _sendRecoveredCrash(
            exception,
            _metaForRecoveredSession(recoveredSession),
          );
        }
      } catch (error, stacktrace) {
        log(
          'Faro: Failed to report recovered Android crash: $error',
          stackTrace: stacktrace,
        );
      }
    }
  }

  Future<void> _reportIOSCrashReports(
    List<String> crashReports, {
    required List<PersistedSessionRecord>? recoveredSessions,
  }) async {
    for (final crashInfo in crashReports) {
      late final FaroException exception;
      PersistedSessionRecord? recoveredSession;
      try {
        final decoded = json.decode(crashInfo);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Crash report must be an object');
        }

        final timestamp = DateTime.tryParse(
          decoded['timestamp']?.toString() ?? '',
        )?.toUtc();
        if (recoveredSessions != null) {
          if (timestamp != null) {
            recoveredSession = _matchRecoveredSessionAt(
              timestamp,
              recoveredSessions,
            );
          }
          if (recoveredSession == null) {
            log('Faro: Ignoring iOS crash without a matching session');
            continue;
          }
        }

        exception = _iosCrashException(
          decoded,
          timestamp: timestamp,
          crashedSessionId: recoveredSession?.currentSessionId,
        );
      } catch (error, stacktrace) {
        log(
          'Faro: Ignoring malformed iOS crash report: $error',
          stackTrace: stacktrace,
        );
        continue;
      }

      try {
        if (_dataCollectionPolicy?.isEnabled == false) {
          continue;
        }
        if (recoveredSession == null) {
          _telemetryRouter.ingest(
            TelemetryItem.fromException(exception),
            activity: SessionActivityKind.passive,
            skipBuffer: true,
          );
        } else if (recoveredSession.isSampled) {
          await _sendRecoveredCrash(
            exception,
            _metaForRecoveredSession(recoveredSession),
          );
        }
      } catch (error, stacktrace) {
        log(
          'Faro: Failed to report recovered iOS crash: $error',
          stackTrace: stacktrace,
        );
      }
    }
  }

  PersistedSessionRecord? _matchRecoveredSession(
    Map<String, dynamic> crashInfo,
    List<PersistedSessionRecord> recoveredSessions, {
    required String? processIdentifier,
  }) {
    if (processIdentifier != null &&
        crashInfo['processName'] != processIdentifier) {
      return null;
    }

    final timestampValue = crashInfo['timestamp'];
    final timestamp = timestampValue is int
        ? timestampValue
        : int.tryParse(timestampValue?.toString() ?? '');
    if (timestamp == null || timestamp < 0) {
      return null;
    }
    final crashTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
      isUtc: true,
    );

    return _matchRecoveredSessionAt(crashTime, recoveredSessions);
  }

  PersistedSessionRecord? _matchRecoveredSessionAt(
    DateTime crashTime,
    List<PersistedSessionRecord> recoveredSessions,
  ) {
    PersistedSessionRecord? match;
    for (final session in recoveredSessions) {
      if (session.startedAt.isAfter(crashTime)) {
        continue;
      }
      // The most recently started eligible session owned the process when the
      // exit occurred. Equal timestamps prefer the later persisted record.
      if (match == null || !session.startedAt.isBefore(match.startedAt)) {
        match = session;
      }
    }
    return match;
  }

  FaroException _iosCrashException(
    Map<String, dynamic> crashInfo, {
    required DateTime? timestamp,
    String? crashedSessionId,
  }) {
    final nativeType = crashInfo['type']?.toString();
    final context = <String, String>{};
    if (nativeType != null && nativeType.isNotEmpty) {
      context['nativeType'] = nativeType;
    }
    if (crashedSessionId != null) {
      context['crashedSessionId'] = crashedSessionId;
    }

    final rawStacktrace = crashInfo['stacktrace'];
    final stacktrace = rawStacktrace is Map
        ? Map<String, dynamic>.from(rawStacktrace)
        : <String, dynamic>{};
    final exception = FaroException(
      'crash',
      crashInfo['value']?.toString() ?? 'Application crash',
      stacktrace,
      fatal: true,
      context: context.isEmpty ? null : context,
    );
    if (timestamp != null) {
      exception.timestamp = timestamp.toIso8601String();
    }
    return exception;
  }

  FaroException _androidCrashException(
    Map<String, dynamic> crashInfo, {
    String? crashedSessionId,
  }) {
    final stringifiedContext = <String, String>{};
    crashInfo.forEach((key, value) {
      stringifiedContext[key] = value?.toString() ?? '';
    });

    final reason = stringifiedContext['reason'] ?? 'UNKNOWN';
    final status = stringifiedContext['status'] ?? 'unknown';
    final timestamp = stringifiedContext['timestamp'] ?? 'No timestamp';
    final readableTimestamp = timestamp.toHumanReadableTimestamp();
    final context = <String, String>{
      'description': stringifiedContext['description'] ?? 'No description',
      'stacktrace':
          stringifiedContext['trace'] ??
          stringifiedContext['stacktrace'] ??
          'No stacktrace',
      'timestamp': timestamp,
      'timestamp_readable_utc': readableTimestamp,
      'importance': stringifiedContext['importance'] ?? 'No importance',
      'processName': stringifiedContext['processName'] ?? 'No processName',
    };
    if (crashedSessionId != null) {
      context['crashedSessionId'] = crashedSessionId;
    }
    final exception = FaroException(
      'crash',
      '$reason, status: $status',
      const <String, dynamic>{},
      fatal: true,
      context: context,
    );
    if (DateTime.tryParse(readableTimestamp) != null) {
      exception.timestamp = readableTimestamp;
    }
    return exception;
  }

  Future<void> _sendRecoveredCrash(
    FaroException exception,
    Meta recoveredCrashMeta,
  ) async {
    if (_dataCollectionPolicy?.isEnabled == false) {
      return;
    }
    // The live batch carries the new session metadata, so recovered crashes
    // must use an isolated payload.
    final payload = Payload(recoveredCrashMeta)..exceptions.add(exception);
    final payloadJson = payload.toJson();
    for (final transport in List<BaseTransport>.of(_transports)) {
      if (transport is FaroTransport) {
        await transport.sendHistorical(payloadJson);
      } else {
        await transport.send(payloadJson);
      }
    }
  }
}
