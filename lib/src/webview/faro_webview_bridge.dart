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
///
/// If your app already tracks the WebView with its own span, pass it to
/// [instrumentedUrl] to propagate that span's trace context instead. The
/// injected `traceparent` then stays the same for every call, and your
/// app keeps full control over the span.
///
/// ```dart
/// final webViewSpan = Faro().startSpanManual('webview');
/// final bridge = FaroWebViewBridge();
/// controller.loadRequest(bridge.instrumentedUrl(myUrl, span: webViewSpan));
///
/// // Your span, your responsibility — bridge.end() will not end it.
/// webViewSpan.end();
/// ```
class FaroWebViewBridge {
  Span? _ownedSpan;

  /// Returns a new [Uri] with `traceparent`, `session.parent_id`, and
  /// `session.parent_app` query parameters appended.
  ///
  /// By default the bridge starts a span that tracks the WebView lifetime
  /// and propagates that span's trace context. The [spanName] defaults to
  /// `'WebView'` but can be customized for different use cases. If called
  /// while a previous bridge-created span is still active, that span is
  /// ended with [SpanStatusCode.error].
  ///
  /// Pass [span] to propagate the trace context of a span your app
  /// already holds, such as one covering the whole WebView lifecycle. The
  /// bridge reads its `traceparent` and otherwise leaves it untouched: no
  /// attributes, no status, and no [end] call, so repeated calls keep
  /// injecting the same `traceparent`. Ending it stays your app's
  /// responsibility, and [spanName] is ignored.
  Uri instrumentedUrl(Uri url, {String spanName = 'WebView', Span? span}) {
    _endOwnedSpan(SpanStatusCode.error, message: 'Superseded by new load');

    final propagatedSpan = span ?? _startOwnedSpan(url, spanName);
    final faro = Faro();

    return url.replace(
      queryParameters: {
        ...url.queryParametersAll,
        'traceparent': propagatedSpan.traceparent,
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
        'session.child_app': ?appName,
      },
    );
  }

  /// Ends the span the bridge started. Call this when the WebView is
  /// disposed or popped from the navigation stack.
  ///
  /// Does nothing when [instrumentedUrl] was given a span: that span
  /// belongs to your app, which is responsible for ending it.
  void end({SpanStatusCode status = SpanStatusCode.ok, String? message}) {
    _endOwnedSpan(status, message: message);
  }

  Span _startOwnedSpan(Uri url, String spanName) {
    final span = Faro().startSpanManual(
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
    _ownedSpan = span;
    return span;
  }

  void _endOwnedSpan(SpanStatusCode status, {String? message}) {
    final span = _ownedSpan;
    if (span == null || span.wasEnded) return;
    span.setStatus(status, message: message);
    span.end();
    _ownedSpan = null;
  }

  static int _defaultPort(String scheme) => scheme == 'https' ? 443 : 80;
}
