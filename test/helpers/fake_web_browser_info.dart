import 'package:device_info_plus/device_info_plus.dart';

WebBrowserInfo createFakeWebBrowserInfo({
  String appVersion = '123.0',
  String language = 'en-US',
  String platform = 'Linux x86_64',
  String userAgent =
      'Mozilla/5.0 Chrome/123.0.0.0 Safari/537.36',
  String vendor = 'Google Inc.',
  int maxTouchPoints = 0,
}) {
  return WebBrowserInfo.fromMap({
    'appCodeName': 'Mozilla',
    'appName': 'Netscape',
    'appVersion': appVersion,
    'deviceMemory': 8.0,
    'language': language,
    'languages': [language],
    'platform': platform,
    'product': 'Gecko',
    'productSub': '20030107',
    'userAgent': userAgent,
    'vendor': vendor,
    'vendorSub': '',
    'hardwareConcurrency': 8,
    'maxTouchPoints': maxTouchPoints,
  });
}
