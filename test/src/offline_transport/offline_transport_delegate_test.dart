import 'dart:async';

import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/offline_transport/mobile_offline_transport_delegate.dart';
import 'package:faro/src/offline_transport/no_op_offline_transport_delegate.dart';
import 'package:faro/src/offline_transport/offline_transport_delegate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlatformInfoProvider extends Mock implements PlatformInfoProvider {}

class _MockInternetConnectivityService extends Mock
    implements InternetConnectivityService {}

void main() {
  group('OfflineTransportDelegateFactory', () {
    late _MockPlatformInfoProvider platformInfoProvider;
    late _MockInternetConnectivityService connectivityService;
    late StreamController<bool> connectivityController;

    setUp(() {
      platformInfoProvider = _MockPlatformInfoProvider();
      connectivityService = _MockInternetConnectivityService();
      connectivityController = StreamController<bool>.broadcast();
      when(() => connectivityService.isOnline).thenReturn(false);
      when(
        () => connectivityService.onConnectivityChanged,
      ).thenAnswer((_) => connectivityController.stream);
    });

    tearDown(() async {
      await connectivityController.close();
    });

    OfflineTransportDelegate createDelegate() {
      return OfflineTransportDelegateFactory(
        platformInfoProvider: platformInfoProvider,
      ).create(
        onReconnected: () async {},
        internetConnectivityService: connectivityService,
      );
    }

    test('creates the mobile delegate when not on web', () {
      when(() => platformInfoProvider.isWeb).thenReturn(false);

      expect(createDelegate(), isA<MobileOfflineTransportDelegate>());
    });

    test('creates the no-op delegate on web', () {
      when(() => platformInfoProvider.isWeb).thenReturn(true);

      expect(createDelegate(), isA<NoOpOfflineTransportDelegate>());
    });

    test('does not touch connectivity on web', () {
      when(() => platformInfoProvider.isWeb).thenReturn(true);

      createDelegate();

      verifyZeroInteractions(connectivityService);
    });
  });

  group('NoOpOfflineTransportDelegate', () {
    test('send and replayCachedData complete without doing anything', () async {
      final delegate = NoOpOfflineTransportDelegate();

      await expectLater(delegate.send({'any': 'payload'}), completes);
      await expectLater(delegate.replayCachedData(), completes);
    });
  });
}
