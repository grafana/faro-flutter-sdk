import 'package:faro/src/faro.dart';
import 'package:faro/src/tracing/span.dart';

/// Bridges trace context and session correlation between a Flutter app
/// and a web app running inside a WebView.
///
/// Creates a span around the WebView lifetime, injects `traceparent` and
/// session correlation query parameters into the URL so the web app can
/// continue the distributed trace, and provides a method to link the
/// web app's session back to the Flutter session.
///
/// The web-side counterpart reads `traceparent` from the URL and sets it
/// as the root OpenTelemetry context. See `InitialParentContextManager`
/// in the example app's `webview_demo/` for a reference implementation.
///
/// Call [end] when the WebView is dismissed (typically in your widget's
/// `dispose` method).
///
/// ```dart
/// final bridge = FaroWebViewBridge();
/// controller.loadRequest(bridge.instrumentedUrl(myUrl));
///
/// // When the web app sends back its session info:
/// bridge.linkChildSession(sessionId: webSessionId, appName: webAppName);
///
/// // When the WebView is dismissed:
/// bridge.end();
/// ```
class FaroWebViewBridge {
  Span? _activeSpan;

  /// Returns a new [Uri] with `traceparent`, `session.parent_id`, and
  /// `session.parent_app` query parameters appended, and starts a span
  /// that tracks the WebView lifetime.
  ///
  /// The [spanName] defaults to `'WebView'` but can be customized for
  /// different use cases.
  ///
  /// If called while a previous span is still active, the previous span
  /// is ended with [SpanStatusCode.error].
  Uri instrumentedUrl(Uri url, {String spanName = 'WebView'}) {
    _endActiveSpan(SpanStatusCode.error, message: 'Superseded by new load');

    final faro = Faro();
    final span = faro.startSpanManual(
      spanName,
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

    return url.replace(
      queryParameters: {
        ...url.queryParametersAll,
        'traceparent': span.traceparent,
        'session.parent_id': faro.meta.session?.id ?? '',
        'session.parent_app': faro.meta.app?.name ?? '',
      },
    );
  }

  /// Pushes a `session.linked` event that correlates the web app's
  /// session with the current Flutter session.
  ///
  /// The parent session information is automatically included via Faro's
  /// session context on the event — only the child session details need
  /// to be provided.
  ///
  /// Call this when the web app sends its Faro session information back
  /// to Flutter (e.g. via a JavaScript channel).
  void linkChildSession({required String sessionId, String? appName}) {
    Faro().pushEvent(
      'session.linked',
      attributes: {
        'session.child_id': sessionId,
        if (appName != null) 'session.child_app': appName,
      },
    );
  }

  /// Ends the active span. Call this when the WebView is disposed or
  /// popped from the navigation stack.
  void end({SpanStatusCode status = SpanStatusCode.ok, String? message}) {
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
