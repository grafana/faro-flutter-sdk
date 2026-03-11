import 'package:faro/faro.dart';

/// Tracks a WebView session as a Faro span and injects a `traceparent`
/// query parameter so the loaded web app can continue the trace.
///
/// This is the **Flutter-side glue** for cross-boundary tracing between a
/// native Flutter app and a web app running inside a WebView. On the web
/// side the counterpart is [InitialParentContextManager] (see
/// `example/webview_demo/src/parentContextManager.js`) which reads the
/// `traceparent` from the URL and sets it as the root OTel context.
///
/// **Note:** This class currently lives in the example app while the
/// approach is being evaluated. It may be promoted into the Faro Flutter
/// SDK in the future. In the meantime, feel free to copy it into your
/// own project and adapt as needed.
///
/// Usage:
/// ```dart
/// final tracker = FaroWebViewTracker();
/// controller.loadRequest(tracker.traceUrl(myUrl));
/// // later, when WebView closes:
/// tracker.end();
/// ```
class FaroWebViewTracker {
  Span? _activeSpan;

  /// Appends a `?traceparent=…` query parameter to [url] and starts
  /// a `WebView` span. Call [end] when the WebView is closed.
  Uri traceUrl(Uri url) {
    _endActiveSpan(SpanStatusCode.error, message: 'Superseded by new load');

    final span = Faro().startSpanManual(
      'WebView',
      attributes: {
        'http.request.method': 'GET',
        'url.full': url.toString(),
        'server.address': url.host,
        'server.port': url.hasPort ? url.port : _defaultPort(url.scheme),
        'url.scheme': url.scheme,
        'component': 'webview',
      },
    );
    _activeSpan = span;

    final traceparent = '00-${span.traceId}-${span.spanId}-01';
    return url.replace(queryParameters: {
      ...url.queryParameters,
      'traceparent': traceparent,
    });
  }

  /// Ends the active span. Call this when the WebView is disposed or
  /// popped from the navigation stack.
  void end({
    SpanStatusCode status = SpanStatusCode.ok,
    String? message,
  }) {
    _endActiveSpan(status, message: message);
  }

  void _endActiveSpan(SpanStatusCode status, {String? message}) {
    final span = _activeSpan;
    if (span == null || span.wasEnded) return;
    span.setStatus(status, message: message);
    span.end();
    _activeSpan = null;
  }

  static int _defaultPort(String scheme) => scheme == 'https' ? 443 : 80;
}
