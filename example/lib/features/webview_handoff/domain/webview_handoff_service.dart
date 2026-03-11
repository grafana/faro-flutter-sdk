import 'package:flutter_riverpod/flutter_riverpod.dart';

final webViewHandoffServiceProvider = Provider<WebViewHandoffService>((ref) {
  return WebViewHandoffService.instance;
});

/// Provides the base URL for the WebView tracing demo.
///
/// The React demo app is expected to run externally (e.g. `npm run dev`).
/// Pass its URL via the `FARO_WEBVIEW_DEMO_URL` dart-define key in
/// `api-config.json`.
class WebViewHandoffService {
  WebViewHandoffService._();

  static final WebViewHandoffService instance = WebViewHandoffService._();

  static const _webViewDemoUrl =
      String.fromEnvironment('FARO_WEBVIEW_DEMO_URL');

  /// Returns `true` when a demo URL has been configured.
  bool get isConfigured => _webViewDemoUrl.isNotEmpty;

  /// Returns the base URL for the WebView demo.
  Uri getBaseUrl() {
    if (!isConfigured) {
      throw StateError(
        'FARO_WEBVIEW_DEMO_URL is not set. '
        'Add it to api-config.json and run the React demo with '
        '`npm run dev` from example/webview_demo/.',
      );
    }
    return Uri.parse(_webViewDemoUrl);
  }
}
