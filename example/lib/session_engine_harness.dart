// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/faro.dart';
import 'package:faro/src/session/session_persistence.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

const _nativeChannel = MethodChannel('faro');
const _reportChannel = MethodChannel('faro_example/session_engine_harness');
const _commandChannel = MethodChannel(
  'faro_example/session_engine_harness_commands',
);

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
    final supportDirectory = await getApplicationSupportDirectory();
    final sessionDirectory = [
      supportDirectory.path,
      'faro',
      'sessions',
    ].join(Platform.pathSeparator);
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

    _commandChannel.setMethodCallHandler((call) async {
      if (call.method == 'resetSession') {
        final previousSessionId = Faro().meta.session?.id;
        await Faro().resetSession();
        return <String, Object?>{
          'previousSessionId': previousSessionId,
          'sessionId': Faro().meta.session?.id,
        };
      }
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

      final recoveryAttempted = await Faro()
          .attemptAndroidCrashRecoveryForTesting(
            <String>[crashReport],
            recoveredSessions: records,
            processIdentifier: arguments['processName'] as String,
          );

      if (!recoveryAttempted) {
        return <String, Object?>{
          'recoveryAttempted': false,
          'liveSessionIdAfter': Faro().meta.session?.id,
          'crashPayloadCount': transport.crashCount(after: payloadCount),
        };
      }

      final crashPayload = await transport.waitForCrash(after: payloadCount);
      final crashSession = _map(_map(crashPayload.payload['meta'])['session']);
      final crashAttributes = _map(crashSession['attributes']);
      final crashException = _map(
        (crashPayload.payload['exceptions'] as List<dynamic>).single,
      );
      final crashContext = _map(crashException['context']);

      return <String, Object?>{
        'recoveryAttempted': true,
        'deliveryMethod': crashPayload.deliveryMethod.name,
        'payloadSessionId': crashSession['id'],
        'payloadPreviousSessionPresent': crashAttributes.containsKey(
          'previousSession',
        ),
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
      'previousSessionPresent':
          attributes?.containsKey('previousSession') ?? false,
      'previousSession': attributes?['previousSession'],
      'processName': attributes?['process_name'],
      'isolateName': attributes?['dart_isolate_name'],
      'ownsSessionPersistence': runtimeInfo?['ownsSessionPersistence'] == true,
      'engineRole': runtimeInfo?['engineRole'],
      'sessionDirectory': sessionDirectory,
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

  final List<_RecordedPayload> _payloads = <_RecordedPayload>[];

  int get payloadCount => _payloads.length;

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    _record(payloadJson, _DeliveryMethod.send);
  }

  @override
  Future<bool> sendHistoricalAcknowledged(
    Map<String, dynamic> payloadJson,
  ) async {
    _record(payloadJson, _DeliveryMethod.historicalAcknowledged);
    return true;
  }

  Future<Map<String, dynamic>> waitForEvent(String name) {
    return _waitFor(
      (record) => _events(record.payload).any((event) => event['name'] == name),
      description: 'event $name',
    ).then((record) => record.payload);
  }

  int eventCount(String name) {
    return _payloads
        .expand((record) => _events(record.payload))
        .where((event) => event['name'] == name)
        .length;
  }

  Future<_RecordedPayload> waitForCrash({required int after}) {
    return _waitFor(
      (record) {
        final exceptions = record.payload['exceptions'];
        return exceptions is List<dynamic> && exceptions.isNotEmpty;
      },
      startIndex: after,
      description: 'recovered crash',
      timeout: const Duration(seconds: 15),
    );
  }

  int crashCount({required int after}) {
    return _payloads.skip(after).where((record) {
      final exceptions = record.payload['exceptions'];
      return exceptions is List<dynamic> && exceptions.isNotEmpty;
    }).length;
  }

  void _record(
    Map<String, dynamic> payloadJson,
    _DeliveryMethod deliveryMethod,
  ) {
    _payloads.add(
      _RecordedPayload(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(payloadJson)) as Map<dynamic, dynamic>,
        ),
        deliveryMethod,
      ),
    );
  }

  Future<_RecordedPayload> _waitFor(
    bool Function(_RecordedPayload) predicate, {
    int startIndex = 0,
    required String description,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (var index = startIndex; index < _payloads.length; index++) {
        final record = _payloads[index];
        if (predicate(record)) {
          return record;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw TimeoutException('Timed out waiting for $description');
  }
}

enum _DeliveryMethod { send, historicalAcknowledged }

class _RecordedPayload {
  const _RecordedPayload(this.payload, this.deliveryMethod);

  final Map<String, dynamic> payload;
  final _DeliveryMethod deliveryMethod;
}
