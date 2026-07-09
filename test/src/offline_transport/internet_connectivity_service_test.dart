import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:faro/src/offline_transport/connectivity_checker.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivityChecker extends Mock implements ConnectivityChecker {}

Future<void> waitForAsyncWork() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  late MockConnectivityChecker mockConnectivity;
  late List<ConnectivityResult> fakeConnectivityResults;
  late StreamController<List<ConnectivityResult>> fakeConnectivityController;
  late InternetConnectivityService service;

  setUp(() {
    mockConnectivity = MockConnectivityChecker();
    fakeConnectivityController =
        StreamController<List<ConnectivityResult>>.broadcast();
    fakeConnectivityResults = [ConnectivityResult.none];

    when(
      () => mockConnectivity.checkConnectivity(),
    ).thenAnswer((_) async => fakeConnectivityResults);
    when(
      () => mockConnectivity.onConnectivityChanged,
    ).thenAnswer((_) => fakeConnectivityController.stream);

    service = InternetConnectivityService(
      connectivity: mockConnectivity,
      internetConnectionCheckerUrl: 'localhost',
      addressLookup: InternetAddress.lookup,
    );
  });

  tearDown(() {
    service.dispose();
    fakeConnectivityController.close();
  });

  group('InternetConnectivityService:', () {
    group('isOnline:', () {
      test('returns false when no connectivity initially', () async {
        fakeConnectivityResults = [ConnectivityResult.none];

        final service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'localhost',
          addressLookup: InternetAddress.lookup,
        );

        await waitForAsyncWork();

        expect(service.isOnline, false);
      });

      test('returns true when connectivity initially', () async {
        fakeConnectivityResults = [ConnectivityResult.mobile];

        final service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'localhost',
          addressLookup: InternetAddress.lookup,
        );

        await waitForAsyncWork();

        expect(service.isOnline, true);
      });

      test('returns false when no connectivity', () async {
        fakeConnectivityController.add([ConnectivityResult.none]);
        await waitForAsyncWork();
        expect(service.isOnline, false);
      });

      test(
        'returns true when has connectivity and internet check succeeds',
        () async {
          fakeConnectivityController.add([ConnectivityResult.wifi]);
          await waitForAsyncWork();
          expect(service.isOnline, true);
        },
      );

      test(
        'returns false when has connectivity but internet check fails',
        () async {
          service = InternetConnectivityService(
            connectivity: mockConnectivity,
            internetConnectionCheckerUrl: 'invalid.domain.that.does.not.exist',
            addressLookup: InternetAddress.lookup,
          );

          fakeConnectivityController.add([ConnectivityResult.wifi]);

          await waitForAsyncWork();

          expect(service.isOnline, false);
        },
      );

      test('returns true when injected lookup resolves an address', () async {
        service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'probe.example',
          addressLookup: (host) async => [InternetAddress('1.1.1.1')],
        );

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();

        expect(service.isOnline, true);
      });

      test('returns false when lookup resolves no addresses', () async {
        service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'probe.example',
          addressLookup: (host) async => [],
        );

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();

        expect(service.isOnline, false);
      });

      test('returns false when lookup hangs longer than the timeout', () async {
        final neverCompletes = Completer<List<InternetAddress>>();
        service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'probe.example',
          addressLookup: (host) => neverCompletes.future,
          lookupTimeout: const Duration(milliseconds: 10),
        );

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();

        expect(service.isOnline, false);
      });

      test(
        'recovers to online once a hanging lookup starts succeeding',
        () async {
          var shouldHang = true;
          service = InternetConnectivityService(
            connectivity: mockConnectivity,
            internetConnectionCheckerUrl: 'probe.example',
            addressLookup: (host) {
              if (shouldHang) {
                return Completer<List<InternetAddress>>().future;
              }
              return Future.value([InternetAddress('1.1.1.1')]);
            },
            lookupTimeout: const Duration(milliseconds: 10),
          );

          fakeConnectivityController.add([ConnectivityResult.wifi]);
          await waitForAsyncWork();
          expect(service.isOnline, false);

          shouldHang = false;
          fakeConnectivityController.add([ConnectivityResult.mobile]);
          await waitForAsyncWork();
          expect(service.isOnline, true);
        },
      );

      test('returns false when lookup throws a SocketException', () async {
        service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'probe.example',
          addressLookup: (host) => throw const SocketException('no route'),
        );

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();

        expect(service.isOnline, false);
      });

      test('returns false when lookup throws a non-socket error', () async {
        service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'probe.example',
          addressLookup: (host) => throw StateError('platform failure'),
        );

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();

        expect(service.isOnline, false);
      });

      test(
        'ignores a stale probe result that completes after a newer probe',
        () async {
          final probes = <Completer<List<InternetAddress>>>[];
          service = InternetConnectivityService(
            connectivity: mockConnectivity,
            internetConnectionCheckerUrl: 'probe.example',
            addressLookup: (host) {
              final probe = Completer<List<InternetAddress>>();
              probes.add(probe);
              return probe.future;
            },
          );

          // First connectivity event: probe 1 starts and stays pending
          // (slow DNS resolution).
          fakeConnectivityController.add([ConnectivityResult.wifi]);
          await waitForAsyncWork();

          // Second connectivity event: probe 2 starts and succeeds
          // quickly -> online.
          fakeConnectivityController.add([ConnectivityResult.mobile]);
          await waitForAsyncWork();
          expect(probes.length, 2);
          probes[1].complete([InternetAddress('1.1.1.1')]);
          await waitForAsyncWork();
          expect(service.isOnline, true);

          // The stale probe 1 now completes as a failure. It must not
          // overwrite the newer online state.
          probes[0].complete(<InternetAddress>[]);
          await waitForAsyncWork();
          expect(service.isOnline, true);
        },
      );

      test('returns false when lookup returns an asynchronous error', () async {
        service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'probe.example',
          addressLookup: (host) async {
            throw const OSError('lookup blocked', 11);
          },
        );

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();

        expect(service.isOnline, false);
      });
    });

    group('onConnectivityChanged:', () {
      test('emits current value on subscription', () async {
        final states = <bool>[];
        final subscription = service.onConnectivityChanged.listen(states.add);
        await waitForAsyncWork();

        expect(states, [false]);
        subscription.cancel();
      });

      test('does not emit same value multiple times', () async {
        final states = <bool>[];
        final subscription = service.onConnectivityChanged.listen(states.add);

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();
        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();
        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();

        expect(states.length, 2);
        expect(states, [false, true]);
        subscription.cancel();
      });

      test('emits when connectivity state changes', () async {
        final states = <bool>[];
        final subscription = service.onConnectivityChanged.listen(states.add);

        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();
        fakeConnectivityController.add([ConnectivityResult.none]);
        await waitForAsyncWork();
        fakeConnectivityController.add([ConnectivityResult.mobile]);
        await waitForAsyncWork();

        expect(states, [false, true, false, true]);
        subscription.cancel();
      });
    });
  });
}
