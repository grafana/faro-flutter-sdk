import 'package:faro/faro.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineTransport:', () {
    test('throws on web platform', () {
      if (PlatformInfoProviderFactory().create().supportsOfflineTransport) {
        expect(
          () => OfflineTransport(
            maxCacheDuration: const Duration(days: 1),
          ),
          returnsNormally,
        );
        return;
      }

      expect(
        () => OfflineTransport(
          maxCacheDuration: const Duration(days: 1),
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains('Flutter web'),
          ),
        ),
      );
    });
  });
}
