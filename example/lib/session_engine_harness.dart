// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';

import 'package:faro/faro.dart';
import 'package:faro/src/session/session_persistence.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _nativeChannel = MethodChannel('faro');
const _reportChannel = MethodChannel('faro_example/session_engine_harness');

Future<void> runSessionEngineHarness(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final label = args.isEmpty ? 'unnamed' : args.first;
  final transport = _HarnessTransport();

  try {
    await Faro().init(
      optionsConfiguration: FaroConfig(
        appName: 'session-engine-harness',
        appVersion: '1.0.0',
        appEnv: 'test',
        apiKey: 'test-api-key',
        collectorUrl: null,
        transports: <FaroTransport>[transport],
        batchConfig: BatchConfig(enabled: false),
        enableFlutterErrorReporting: false,
        enableCrashReporting: false,
        memoryUsageVitals: false,
        cpuUsageVitals: false,
        anrTracking: false,
        refreshRateVitals: false,
        enableUiActivityMonitoring: false,
        persistUser: false,
        persistSession: true,
      ),
    );
    Faro().enableDataCollection = true;

    final runtimeInfo = await _nativeChannel.invokeMapMethod<String, dynamic>(
      'getSessionRuntimeInfo',
      {'claimSessionPersistence': false},
    );
    final session = Faro().meta.session;
    final attributes = session?.attributes;

    Faro().pushEvent(
      'session_engine_probe',
      attributes: <String, dynamic>{'engine_label': label},
    );
    final telemetryPayload = await transport.waitForEvent(
      'session_engine_probe',
    );
    final telemetrySession = _map(_map(telemetryPayload['meta'])['session']);
    final telemetryAttributes = _map(telemetrySession['attributes']);
    final probeEvent = _events(
      telemetryPayload,
    ).firstWhere((event) => event['name'] == 'session_engine_probe');

    _reportChannel.setMethodCallHandler((call) async {
      if (call.method != 'reportRecoveredCrash') {
        throw MissingPluginException('Unknown harness method ${call.method}');
      }
      final arguments = _map(call.arguments);
      final records = (arguments['recoveredSessions'] as List<dynamic>)
          .map((record) => PersistedSessionRecord.fromJson(_map(record)))
          .toList();
      final crashedSessionId = arguments['crashedSessionId'] as String;
      final crashedSession = records.firstWhere(
        (record) => record.currentSessionId == crashedSessionId,
      );
      final crashTimestamp = _crashTimestampWithin(crashedSession, records);
      final payloadCount = transport.payloadCount;
      final crashReport = jsonEncode(<String, dynamic>{
        'reason': 'CRASH',
        'status': 0,
        'description': 'Secondary-engine attribution probe',
        'timestamp': crashTimestamp,
        'importance': 100,
        'processName': arguments['processName'],
      });

      await Faro().reportAndroidCrashesForTesting(
        <String>[crashReport],
        recoveredSessions: records,
        processIdentifier: arguments['processName'] as String,
      );

      final crashPayload = await transport.waitForCrash(after: payloadCount);
      final crashSession = _map(_map(crashPayload['meta'])['session']);
      final crashAttributes = _map(crashSession['attributes']);
      final crashException = _map(
        (crashPayload['exceptions'] as List<dynamic>).single,
      );
      final crashContext = _map(crashException['context']);

      return <String, Object?>{
        'payloadSessionId': crashSession['id'],
        'payloadPreviousSession': crashAttributes['previousSession'],
        'crashedSessionId': crashContext['crashedSessionId'],
        'fatal': crashException['fatal'],
        'liveSessionIdAfter': Faro().meta.session?.id,
        'crashPayloadCount': transport.crashCount(after: payloadCount),
      };
    });

    await _reportChannel.invokeMethod<void>('report', <String, Object?>{
      'label': label,
      'sessionId': session?.id,
      'previousSession': attributes?['previousSession'],
      'processName': attributes?['process_name'],
      'isolateName': attributes?['dart_isolate_name'],
      'ownsSessionPersistence': runtimeInfo?['ownsSessionPersistence'] == true,
      'engineRole': runtimeInfo?['engineRole'],
      'telemetrySessionId': telemetrySession['id'],
      'telemetryPreviousSession': telemetryAttributes['previousSession'],
      'telemetryProcessName': telemetryAttributes['process_name'],
      'telemetryIsolateName': telemetryAttributes['dart_isolate_name'],
      'telemetryProbeLabel': _map(probeEvent['attributes'])['engine_label'],
      'telemetryProbeCount': transport.eventCount('session_engine_probe'),
    });
  } catch (error, stackTrace) {
    await _reportChannel.invokeMethod<void>('report', <String, Object?>{
      'label': label,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
  }
}

Map<String, dynamic> _map(Object? value) {
  return Map<String, dynamic>.from(value! as Map<dynamic, dynamic>);
}

List<Map<String, dynamic>> _events(Map<String, dynamic> payload) {
  return (payload['events'] as List<dynamic>? ?? const <dynamic>[])
      .map((event) => _map(event))
      .toList();
}

int _crashTimestampWithin(
  PersistedSessionRecord crashedSession,
  List<PersistedSessionRecord> records,
) {
  final timestamp = crashedSession.startedAt.millisecondsSinceEpoch + 1;
  final crashTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  final laterStarts =
      records
          .map((record) => record.startedAt)
          .where((startedAt) => startedAt.isAfter(crashedSession.startedAt))
          .toList()
        ..sort();
  if (laterStarts.isNotEmpty && !crashTime.isBefore(laterStarts.first)) {
    throw StateError('No millisecond inside the crashed session interval');
  }
  return timestamp;
}

class _HarnessTransport extends FaroTransport {
  _HarnessTransport()
    : super(
        collectorUrl: 'https://example.invalid',
        apiKey: 'test-api-key',
        sessionIdResolver: () => Faro().meta.session?.id ?? '',
      );

  final List<Map<String, dynamic>> _payloads = <Map<String, dynamic>>[];

  int get payloadCount => _payloads.length;

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    _record(payloadJson);
  }

  @override
  Future<bool> sendHistoricalAcknowledged(
    Map<String, dynamic> payloadJson,
  ) async {
    _record(payloadJson);
    return true;
  }

  Future<Map<String, dynamic>> waitForEvent(String name) {
    return _waitFor(
      (payload) => _events(payload).any((event) => event['name'] == name),
      description: 'event $name',
    );
  }

  int eventCount(String name) {
    return _payloads
        .expand(_events)
        .where((event) => event['name'] == name)
        .length;
  }

  Future<Map<String, dynamic>> waitForCrash({required int after}) {
    return _waitFor(
      (payload) {
        final exceptions = payload['exceptions'];
        return exceptions is List<dynamic> && exceptions.isNotEmpty;
      },
      startIndex: after,
      description: 'recovered crash',
    );
  }

  int crashCount({required int after}) {
    return _payloads.skip(after).where((payload) {
      final exceptions = payload['exceptions'];
      return exceptions is List<dynamic> && exceptions.isNotEmpty;
    }).length;
  }

  void _record(Map<String, dynamic> payloadJson) {
    _payloads.add(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(payloadJson)) as Map<dynamic, dynamic>,
      ),
    );
  }

  Future<Map<String, dynamic>> _waitFor(
    bool Function(Map<String, dynamic>) predicate, {
    int startIndex = 0,
    required String description,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      for (var index = startIndex; index < _payloads.length; index++) {
        final payload = _payloads[index];
        if (predicate(payload)) {
          return payload;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException('Timed out waiting for $description');
  }
}
