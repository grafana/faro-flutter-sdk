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

  const listenedNative = <String, dynamic>{
    'batteryLevel': 87,
    'isCharging': false,
    'lowPowerMode': true,
    'thermalState': 'fair',
    'connectionType': 'cell',
    'reachable': true,
  };
  const criticalNative = <String, dynamic>{
    'batteryLevel': 87,
    'isCharging': false,
    'lowPowerMode': true,
    'thermalState': 'critical',
    'connectionType': 'cell',
    'reachable': true,
  };
  const probedNative = <String, dynamic>{
    'connectionSubtype': 'lte',
    'carrierName': 'Example Mobile',
  };
  const nativeState = <String, dynamic>{...listenedNative, ...probedNative};

  DynamicDeviceStateProvider createProvider({
    DateTime Function()? currentTime,
  }) {
    return DynamicDeviceStateProvider(
      nativeMethods: nativeMethods,
      platformInfoProvider: platformInfoProvider,
      currentTime: currentTime ?? DateTime.now,
    );
  }

  setUp(() {
    nativeMethods = MockFaroNativeMethods();
    platformInfoProvider = MockPlatformInfoProvider();
    when(() => platformInfoProvider.isAndroid).thenReturn(true);
    when(() => platformInfoProvider.isIOS).thenReturn(false);
    when(
      () => nativeMethods.getListenedDeviceState(),
    ).thenAnswer((_) async => listenedNative);
    when(
      () => nativeMethods.getProbedDeviceState(),
    ).thenAnswer((_) async => probedNative);
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
        'reachable': true,
      });
    });

    test('keeps false and zero, which are real values', () {
      final state = DynamicDeviceState.fromNative({
        'batteryLevel': 0,
        'isCharging': false,
        'lowPowerMode': false,
        'reachable': false,
      });

      expect(state.device.batteryLevel, 0);
      expect(state.device.isCharging, isFalse);
      expect(state.device.lowPowerMode, isFalse);
      expect(state.network.reachable, isFalse);
    });

    test('drops a value of the wrong type or range', () {
      final state = DynamicDeviceState.fromNative({
        'batteryLevel': 101,
        'isCharging': 'yes',
        'thermalState': 'toasty',
        'connectionType': 'satellite',
        'carrierName': '',
        'reachable': 1,
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

    test('start reads the listened values, then the probed ones', () async {
      final provider = createProvider();

      await provider.start();
      await provider.refreshProbed();

      expect(provider.current?.device.batteryLevel, 87);
      expect(provider.current?.network.connectionType, 'cell');
      expect(provider.current?.network.carrierName, 'Example Mobile');
      verifyInOrder([
        () => nativeMethods.getListenedDeviceState(),
        () => nativeMethods.getProbedDeviceState(),
      ]);
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

    test('a pushed change shows at once and costs no native read', () async {
      final provider = createProvider();
      await provider.start();
      clearInteractions(nativeMethods);

      provider.applyListened({...listenedNative, 'batteryLevel': 12});

      expect(provider.current?.device.batteryLevel, 12);
      verifyNever(() => nativeMethods.getListenedDeviceState());
      verifyNever(() => nativeMethods.getProbedDeviceState());
      provider.dispose();
    });

    test('an older snapshot never replaces a newer one', () async {
      final provider = createProvider();
      await provider.start();

      provider.applyListened({
        ...listenedNative,
        'version': 2,
        'batteryLevel': 50,
      });
      provider.applyListened({
        ...listenedNative,
        'version': 1,
        'batteryLevel': 70,
      });

      expect(provider.current?.device.batteryLevel, 50);
      provider.dispose();
    });

    test('a late reply to the first read does not undo a newer push', () async {
      // The reply carries version 1 and arrives after a push with version 2.
      final reply = Completer<Map<String, dynamic>?>();
      when(
        () => nativeMethods.getListenedDeviceState(),
      ).thenAnswer((_) => reply.future);
      final provider = createProvider();
      final started = provider.start();

      provider.applyListened({
        ...listenedNative,
        'version': 2,
        'connectionType': 'wifi',
      });
      reply.complete({...listenedNative, 'version': 1});
      await started;

      expect(provider.current?.network.connectionType, 'wifi');
      provider.dispose();
    });

    test('a change pushed over the channel reaches the provider', () async {
      final provider = createProvider();
      await provider.start();
      const codec = StandardMethodCodec();

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            DynamicDeviceStateProvider.changeChannelName,
            codec.encodeMethodCall(
              const MethodCall('onDynamicDeviceStateChanged', criticalNative),
            ),
            (_) {},
          );

      expect(provider.current?.device.thermalState, 'critical');
      provider.dispose();
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
        verifyNever(() => nativeMethods.getListenedDeviceState());
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

    test('a failed listened read leaves no value and never throws', () async {
      when(
        () => nativeMethods.getListenedDeviceState(),
      ).thenThrow(Exception('channel down'));
      final provider = createProvider();

      await provider.start();

      expect(provider.current, isNull);
      provider.dispose();
    });

    test('a null answer from native leaves no value', () async {
      when(
        () => nativeMethods.getListenedDeviceState(),
      ).thenAnswer((_) async => null);
      final provider = createProvider();

      await provider.start();

      expect(provider.current, isNull);
      provider.dispose();
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
        verify(() => nativeMethods.getListenedDeviceState()).called(1);
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
      verifyNever(() => nativeMethods.getListenedDeviceState());
      verifyNever(() => nativeMethods.getProbedDeviceState());
    });
  });
}
