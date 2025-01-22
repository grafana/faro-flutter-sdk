import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rum_sdk/src/offline_transport/connectivity_checker.dart';
import 'package:rum_sdk/src/offline_transport/internet_connectivity_service.dart';

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

    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => fakeConnectivityResults);
    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => fakeConnectivityController.stream);

    service = InternetConnectivityService(
      connectivity: mockConnectivity,
      internetConnectionCheckerUrl: 'localhost',
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
        );

        await waitForAsyncWork();

        expect(service.isOnline, false);
      });

      test('returns true when connectivity initially', () async {
        fakeConnectivityResults = [ConnectivityResult.mobile];

        final service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'localhost',
        );

        await waitForAsyncWork();

        expect(service.isOnline, true);
      });

      test('returns false when no connectivity', () async {
        fakeConnectivityController.add([ConnectivityResult.none]);
        await waitForAsyncWork();
        expect(service.isOnline, false);
      });

      test('returns true when has connectivity and internet check succeeds',
          () async {
        fakeConnectivityController.add([ConnectivityResult.wifi]);
        await waitForAsyncWork();
        expect(service.isOnline, true);
      });

      test('returns false when has connectivity but internet check fails',
          () async {
        service = InternetConnectivityService(
          connectivity: mockConnectivity,
          internetConnectionCheckerUrl: 'invalid.domain.that.does.not.exist',
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
