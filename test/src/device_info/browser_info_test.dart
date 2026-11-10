import 'package:device_info_plus/device_info_plus.dart';
import 'package:faro/src/device_info/device_info_provider.dart';
import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

class _MockWebBrowserInfo extends Mock implements WebBrowserInfo {}

class _MockPlatformInfoProvider extends Mock implements PlatformInfoProvider {}

class _MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

const _chromeMac =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/157.0.8103.39 Safari/537.36';
const _safariIphone =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 '
    'Safari/604.1';

void main() {
  late _MockDeviceInfoPlugin deviceInfoPlugin;
  late _MockPlatformInfoProvider platformInfoProvider;
  late DeviceInfoProvider sut;

  setUp(() {
    deviceInfoPlugin = _MockDeviceInfoPlugin();
    platformInfoProvider = _MockPlatformInfoProvider();
    sut = DeviceInfoProvider(
      deviceInfoPlugin: deviceInfoPlugin,
      platformInfoProvider: platformInfoProvider,
      nativeMethods: _MockFaroNativeMethods(),
    );
  });

  void stubWeb({
    required BrowserName name,
    required String userAgent,
    String platform = 'MacIntel',
    String language = 'en-US',
  }) {
    final info = _MockWebBrowserInfo();
    when(() => info.browserName).thenReturn(name);
    when(() => info.userAgent).thenReturn(userAgent);
    when(() => info.platform).thenReturn(platform);
    when(() => info.language).thenReturn(language);
    when(() => platformInfoProvider.isWeb).thenReturn(true);
    when(() => deviceInfoPlugin.webBrowserInfo).thenAnswer((_) async => info);
  }

  group('DeviceInfoProvider.getBrowser', () {
    test('returns null when not running on the web', () async {
      when(() => platformInfoProvider.isWeb).thenReturn(false);

      expect(await sut.getBrowser(), isNull);
      verifyNever(() => deviceInfoPlugin.webBrowserInfo);
    });

    test('maps desktop browser details', () async {
      stubWeb(name: BrowserName.chrome, userAgent: _chromeMac);

      final browser = await sut.getBrowser();

      expect(browser?.name, 'chrome');
      expect(browser?.version, '157.0.8103.39');
      expect(browser?.os, 'MacIntel');
      expect(browser?.userAgent, _chromeMac);
      expect(browser?.language, 'en-US');
      expect(browser?.mobile, isFalse);
    });

    test('flags mobile browsers', () async {
      stubWeb(
        name: BrowserName.safari,
        userAgent: _safariIphone,
        platform: 'iPhone',
      );

      final browser = await sut.getBrowser();

      expect(browser?.name, 'safari');
      expect(browser?.version, '17.4');
      expect(browser?.mobile, isTrue);
    });

    test('reports unknown browsers without a version', () async {
      stubWeb(name: BrowserName.unknown, userAgent: 'SomethingElse/1.0');

      final browser = await sut.getBrowser();

      expect(browser?.name, 'unknown');
      expect(browser?.version, isEmpty);
    });

    test('returns null instead of throwing when the plugin fails', () async {
      when(() => platformInfoProvider.isWeb).thenReturn(true);
      when(() => deviceInfoPlugin.webBrowserInfo).thenThrow(StateError('boom'));

      expect(await sut.getBrowser(), isNull);
    });
  });

  group('parseBrowserVersion', () {
    test('parses each supported browser', () {
      expect(
        parseBrowserVersion(BrowserName.firefox, 'Gecko Firefox/130.0'),
        '130.0',
      );
      expect(
        parseBrowserVersion(BrowserName.edge, 'Chrome/120.0 Edg/120.0.2210.91'),
        '120.0.2210.91',
      );
      expect(
        parseBrowserVersion(BrowserName.opera, 'OPR/110.0.0.0'),
        '110.0.0.0',
      );
      expect(
        parseBrowserVersion(BrowserName.samsungInternet, 'SamsungBrowser/25.0'),
        '25.0',
      );
    });

    test('returns an empty string when the version is missing', () {
      expect(parseBrowserVersion(BrowserName.chrome, 'no version'), isEmpty);
      expect(parseBrowserVersion(BrowserName.unknown, _chromeMac), isEmpty);
    });
  });
}
