import 'package:faro/src/native_platform_interaction/faro_sdk_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelFaroSdk.getProcessVitals', () {
    final platform = MethodChannelFaroSdk();
    final calls = <MethodCall>[];
    Object? reply;

    setUp(() {
      calls.clear();
      reply = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (call) async {
            calls.add(call);
            return reply;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null);
    });

    test('calls getProcessVitals on the faro channel', () async {
      await platform.getProcessVitals(cpu: true, memory: true);
      expect(platform.methodChannel.name, 'faro');
      expect(calls.single.method, 'getProcessVitals');
    });

    test('sends which counters to read', () async {
      await platform.getProcessVitals(cpu: true, memory: false);
      await platform.getProcessVitals(cpu: false, memory: true);
      expect(calls.map((call) => call.arguments), [
        {'cpu': true, 'memory': false},
        {'cpu': false, 'memory': true},
      ]);
    });

    test('returns the native reply as a string-keyed map', () async {
      reply = {
        'monotonicNanos': 42,
        'timestampMillis': 1795435200123,
        'cpuTimeSeconds': 3.25,
        'cpuCount': 8,
        'memoryBytes': 1024,
        'memoryBasis': 'phys_footprint',
      };
      final result = await platform.getProcessVitals(cpu: true, memory: true);
      expect(result, isA<Map<String, dynamic>>());
      expect(result, reply);
    });

    test('returns null when native replies with null', () async {
      expect(await platform.getProcessVitals(cpu: true, memory: true), isNull);
    });

    test('surfaces a native error to the caller', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, (call) async {
            throw PlatformException(code: 'NATIVE_ERROR');
          });
      // The sampler turns this into a failed read; it must not be swallowed
      // here as an empty reading.
      expect(
        platform.getProcessVitals(cpu: true, memory: true),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
