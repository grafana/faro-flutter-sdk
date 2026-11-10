import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:faro/src/device_info/dynamic_device_state_provider.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

class MockPlatformInfoProvider extends Mock implements PlatformInfoProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFaroNativeMethods nativeMethods;
  late MockPlatformInfoProvider platformInfoProvider;
  late StreamController<Object?> changes;
  late Object? firstEvent;

  const listenedNative = <String, dynamic>{
    'batteryLevel': 87,
    'isCharging': false,
    'lowPowerMode': true,
    'thermalState': 'fair',
    'connectionType': 'cell',
  };
  const criticalNative = <String, dynamic>{
    'batteryLevel': 87,
    'isCharging': false,
    'lowPowerMode': true,
    'thermalState': 'critical',
    'connectionType': 'cell',
  };
  const probedNative = <String, dynamic>{
    'connectionSubtype': 'lte',
    'carrierName': 'Example Mobile',
  };
  const nativeState = <String, dynamic>{...listenedNative, ...probedNative};

  DynamicDeviceStateProvider createProvider({
    DateTime Function()? currentTime,
    Stream<Object?> Function()? openChangeStream,
  }) {
    return DynamicDeviceStateProvider(
      nativeMethods: nativeMethods,
      platformInfoProvider: platformInfoProvider,
      currentTime: currentTime ?? DateTime.now,
      openChangeStream: openChangeStream ?? () => changes.stream,
    );
  }

  setUp(() {
    nativeMethods = MockFaroNativeMethods();
    platformInfoProvider = MockPlatformInfoProvider();
    when(() => platformInfoProvider.isAndroid).thenReturn(true);
    when(() => platformInfoProvider.isIOS).thenReturn(false);
    // Like the native side: the first event holds the current values.
    firstEvent = listenedNative;
    changes = StreamController<Object?>.broadcast(
      onListen: () {
        final event = firstEvent;
        if (event is Error || event is Exception) {
          changes.addError(event!);
        } else if (event != null) {
          changes.add(event);
        }
      },
    );
    when(
      () => nativeMethods.getProbedDeviceState(),
    ).thenAnswer((_) async => probedNative);
  });

  tearDown(() async {
    await changes.close();
  });

  group('DynamicDeviceState.fromNative', () {
    test('reads every dynamic field', () {
      final state = DynamicDeviceState.fromNative(nativeState);

      expect(state.device.toJson(), {
        'battery_level': 87,
        'is_charging': false,
        'low_power_mode': true,
        'thermal_state': 'fair',
      });
      expect(state.network.toJson(), {
        'connection_type': 'cell',
        'connection_subtype': 'lte',
        'carrier_name': 'Example Mobile',
      });
    });

    test('keeps false and zero, which are real values', () {
      final state = DynamicDeviceState.fromNative({
        'batteryLevel': 0,
        'isCharging': false,
        'lowPowerMode': false,
      });

      expect(state.device.batteryLevel, 0);
      expect(state.device.isCharging, isFalse);
      expect(state.device.lowPowerMode, isFalse);
    });

    test('drops a value of the wrong type or range', () {
      final state = DynamicDeviceState.fromNative({
        'batteryLevel': 101,
        'isCharging': 'yes',
        'thermalState': 'toasty',
        'connectionType': 'satellite',
        'carrierName': '',
      });

      expect(state.device.toJson(), isEmpty);
      expect(state.network.toJson(), isEmpty);
    });

    test('one bad field does not cost the others', () {
      final state = DynamicDeviceState.fromNative({
        'batteryLevel': -3,
        'thermalState': 'serious',
      });

      expect(state.device.toJson(), {'thermal_state': 'serious'});
    });
  });

  group('DynamicDeviceStateProvider', () {
    DynamicDeviceStateProvider createFakeClockProvider(FakeAsync async) {
      return createProvider(currentTime: async.getClock(DateTime(2026)).now);
    }

    test('has no value before the first read', () {
      expect(createProvider().current, isNull);
    });

    test('start takes the first listened values, then reads the probed '
        'ones', () async {
      final provider = createProvider();

      await provider.start();
      await provider.refreshProbed();

      expect(provider.current?.device.batteryLevel, 87);
      expect(provider.current?.network.connectionType, 'cell');
      expect(provider.current?.network.carrierName, 'Example Mobile');
      verify(() => nativeMethods.getProbedDeviceState()).called(1);
      provider.dispose();
    });

    test('start does not wait for the probed read', () {
      fakeAsync((async) {
        when(() => nativeMethods.getProbedDeviceState()).thenAnswer(
          (_) => Future<Map<String, dynamic>?>.delayed(
            const Duration(seconds: 5),
            () => probedNative,
          ),
        );
        final provider = createFakeClockProvider(async);
        var started = false;

        provider.start().then((_) => started = true);
        async.flushMicrotasks();

        expect(started, isTrue);
        expect(provider.current?.device.batteryLevel, 87);
        expect(provider.current?.network.carrierName, isNull);
        async.elapse(const Duration(seconds: 5));
        expect(provider.current?.network.carrierName, 'Example Mobile');
        provider.dispose();
      });
    });

    test('a streamed change shows at once and costs no native read', () async {
      final provider = createProvider();
      await provider.start();
      clearInteractions(nativeMethods);

      changes.add({...listenedNative, 'batteryLevel': 12});
      await pumpEventQueue();

      expect(provider.current?.device.batteryLevel, 12);
      verifyNever(() => nativeMethods.getProbedDeviceState());
      provider.dispose();
    });

    test('a later event replaces an earlier one', () async {
      final provider = createProvider();
      await provider.start();

      changes
        ..add({...listenedNative, 'batteryLevel': 50})
        ..add({...listenedNative, 'batteryLevel': 70});
      await pumpEventQueue();

      expect(provider.current?.device.batteryLevel, 70);
      provider.dispose();
    });

    test('an event that is not a map is ignored', () async {
      final provider = createProvider();
      await provider.start();

      changes.add('not a map');
      await pumpEventQueue();

      expect(provider.current?.device.batteryLevel, 87);
      provider.dispose();
    });

    test('values stream over the real event channel', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = EventChannel(
        DynamicDeviceStateProvider.changeChannelName,
      );
      MockStreamHandlerEventSink? sink;
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            sink = events..success(listenedNative);
          },
        ),
      );
      final provider = DynamicDeviceStateProvider(
        nativeMethods: nativeMethods,
        platformInfoProvider: platformInfoProvider,
      );

      await provider.start();
      expect(provider.current?.device.thermalState, 'fair');

      sink?.success(criticalNative);
      await pumpEventQueue();

      expect(provider.current?.device.thermalState, 'critical');
      provider.dispose();
      messenger.setMockStreamHandler(channel, null);
    });

    test('listened values never expire', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();

        async.elapse(const Duration(hours: 1));

        expect(provider.current?.device.batteryLevel, 87);
        expect(provider.current?.network.connectionType, 'cell');
        provider.dispose();
      });
    });

    test('a probed value is still served while a new read runs', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 30));

        expect(provider.current?.network.carrierName, 'Example Mobile');
        provider.dispose();
      });
    });

    test('a probed value older than 60 seconds is left out', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 60));
        expect(provider.current?.network.carrierName, 'Example Mobile');

        async.elapse(const Duration(milliseconds: 1));
        expect(provider.current?.network.carrierName, isNull);
        expect(provider.current?.device.batteryLevel, 87);
        provider.dispose();
      });
    });

    test('refreshIfStale reads the probed values once while fresh', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();
        clearInteractions(nativeMethods);

        provider.refreshIfStale();
        provider.refreshIfStale();
        async.flushMicrotasks();

        verifyNever(() => nativeMethods.getProbedDeviceState());
        provider.dispose();
      });
    });

    test('a stale probed value triggers one new read', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();
        clearInteractions(nativeMethods);

        async.elapse(const Duration(seconds: 6));
        provider.refreshIfStale();
        provider.refreshIfStale();
        async.flushMicrotasks();

        verify(() => nativeMethods.getProbedDeviceState()).called(1);
        expect(provider.current?.network.carrierName, 'Example Mobile');
        provider.dispose();
      });
    });

    test('refreshIfStale does not wait for the native read', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 6));
        when(() => nativeMethods.getProbedDeviceState()).thenAnswer(
          (_) => Future<Map<String, dynamic>?>.delayed(
            const Duration(seconds: 1),
            () => const {'carrierName': 'New Carrier'},
          ),
        );

        provider.refreshIfStale();

        // The old value carries the signal while the read runs.
        expect(provider.current?.network.carrierName, 'Example Mobile');
        async.elapse(const Duration(seconds: 1));
        expect(provider.current?.network.carrierName, 'New Carrier');
        provider.dispose();
      });
    });

    test('a connection type change drops only the network subtype', () async {
      final provider = createProvider();
      await provider.start();
      await provider.refreshProbed();

      provider.applyListened({...listenedNative, 'connectionType': 'wifi'});

      expect(provider.current?.network.connectionType, 'wifi');
      expect(provider.current?.network.connectionSubtype, isNull);
      // The carrier belongs to the SIM, not to the network.
      expect(provider.current?.network.carrierName, 'Example Mobile');
      provider.dispose();
    });

    test('a connection type change reads the probed values at once', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();
        clearInteractions(nativeMethods);

        provider.applyListened({...listenedNative, 'connectionType': 'wifi'});
        provider.refreshIfStale();
        async.flushMicrotasks();

        // The last read is under 5 seconds old, yet the change forces one.
        verify(() => nativeMethods.getProbedDeviceState()).called(1);
        provider.dispose();
      });
    });

    test('a read that began before a network change is discarded', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();
        when(() => nativeMethods.getProbedDeviceState()).thenAnswer(
          (_) => Future<Map<String, dynamic>?>.delayed(
            const Duration(seconds: 2),
            () => const {'connectionSubtype': 'nr'},
          ),
        );
        async.elapse(const Duration(seconds: 6));
        provider.refreshIfStale();

        provider.applyListened({...listenedNative, 'connectionType': 'wifi'});
        async.elapse(const Duration(seconds: 2));

        // The answer was about the old network, so it does not show.
        expect(provider.current?.network.connectionSubtype, isNull);
        provider.dispose();
      });
    });

    test(
      'a change that keeps the connection type keeps the probed values',
      () async {
        final provider = createProvider();
        await provider.start();
        await provider.refreshProbed();

        provider.applyListened({...listenedNative, 'batteryLevel': 50});

        expect(provider.current?.network.carrierName, 'Example Mobile');
        provider.dispose();
      },
    );

    test('a failed probed read leaves the listened values', () async {
      when(
        () => nativeMethods.getProbedDeviceState(),
      ).thenThrow(Exception('channel down'));
      final provider = createProvider();

      await provider.start();

      expect(provider.current?.device.batteryLevel, 87);
      expect(provider.current?.network.carrierName, isNull);
      provider.dispose();
    });

    test('a failed probed read is not retried for 30 seconds', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();
        when(
          () => nativeMethods.getProbedDeviceState(),
        ).thenThrow(Exception('channel down'));
        async.elapse(const Duration(seconds: 6));
        provider.refreshIfStale();
        async.flushMicrotasks();
        clearInteractions(nativeMethods);

        async.elapse(const Duration(seconds: 29));
        provider.refreshIfStale();
        provider.refreshIfStale();
        async.flushMicrotasks();
        verifyNever(() => nativeMethods.getProbedDeviceState());

        async.elapse(const Duration(seconds: 1));
        provider.refreshIfStale();
        async.flushMicrotasks();
        verify(() => nativeMethods.getProbedDeviceState()).called(1);
        provider.dispose();
      });
    });

    test('a successful read clears the backoff', () {
      fakeAsync((async) {
        final provider = createFakeClockProvider(async);
        provider.start();
        async.flushMicrotasks();
        when(
          () => nativeMethods.getProbedDeviceState(),
        ).thenThrow(Exception('channel down'));
        async.elapse(const Duration(seconds: 6));
        provider.refreshIfStale();
        async.flushMicrotasks();
        when(
          () => nativeMethods.getProbedDeviceState(),
        ).thenAnswer((_) async => probedNative);
        async.elapse(const Duration(seconds: 31));
        provider.refreshIfStale();
        async.flushMicrotasks();
        clearInteractions(nativeMethods);

        async.elapse(const Duration(seconds: 6));
        provider.refreshIfStale();
        async.flushMicrotasks();

        verify(() => nativeMethods.getProbedDeviceState()).called(1);
        provider.dispose();
      });
    });

    test('a stream error leaves no value and never throws', () async {
      firstEvent = Exception('channel down');
      final provider = createProvider();

      await provider.start();

      expect(provider.current, isNull);
      provider.dispose();
    });

    test('no first event leaves no value after the timeout', () {
      fakeAsync((async) {
        firstEvent = null;
        final provider = createProvider();
        var started = false;

        provider.start().then((_) => started = true);
        async.elapse(const Duration(seconds: 1));
        expect(started, isFalse);
        async.elapse(const Duration(seconds: 1));

        expect(started, isTrue);
        expect(provider.current, isNull);
        verifyNever(() => nativeMethods.getProbedDeviceState());
        provider.dispose();
      });
    });

    test('values that arrive after the timeout still apply', () {
      fakeAsync((async) {
        firstEvent = null;
        final provider = createProvider();
        provider.start();
        async.elapse(const Duration(seconds: 2));

        changes.add(listenedNative);
        async.flushMicrotasks();

        expect(provider.current?.device.batteryLevel, 87);
        provider.dispose();
      });
    });

    test('dispose stops listening', () async {
      final provider = createProvider();
      await provider.start();

      provider.dispose();

      expect(changes.hasListener, isFalse);
    });

    test('iOS has no probed values, so it never reads them', () {
      fakeAsync((async) {
        when(() => platformInfoProvider.isAndroid).thenReturn(false);
        when(() => platformInfoProvider.isIOS).thenReturn(true);
        final provider = createFakeClockProvider(async);

        provider.start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));
        provider.refreshIfStale();
        provider.applyListened({...listenedNative, 'connectionType': 'wifi'});
        provider.refreshIfStale();
        async.flushMicrotasks();

        expect(provider.current?.device.batteryLevel, 87);
        verifyNever(() => nativeMethods.getProbedDeviceState());
        provider.dispose();
      });
    });

    test('never calls native on a platform without native values', () async {
      when(() => platformInfoProvider.isAndroid).thenReturn(false);
      final provider = createProvider();

      await provider.start();
      provider.refreshIfStale();

      expect(provider.current, isNull);
      expect(changes.hasListener, isFalse);
      verifyNever(() => nativeMethods.getProbedDeviceState());
    });
  });
}
