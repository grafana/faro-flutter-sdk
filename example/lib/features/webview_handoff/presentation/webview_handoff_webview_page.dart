import 'dart:convert';

import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the React demo inside a WebView.
///
/// Uses [FaroWebViewBridge] to inject `traceparent` and `session.parent_*`
/// query parameters into the URL so the web app can continue the Flutter
/// trace and identify its originating session.
///
/// Demonstrates both span ownership models. With [useAppOwnedSpan] off,
/// the bridge starts and ends its own `WebView` span, and each reload
/// supersedes it with a new span and a new `traceparent`. With it on, this
/// page starts a span covering the whole WebView lifecycle and passes it
/// to `instrumentedUrl`, so reloads keep propagating the same
/// `traceparent` and ending the span is up to this page.
///
/// A `HandoffBridge` JavaScript channel is registered so the React app
/// can send messages back. Supported message types:
/// - `faro_session` — the web app's Faro session ID, used to push a
///   `session.linked` event with `session.child_*` attributes.
/// - `login_result` — login result data; auto-pops the page.
class WebViewHandoffWebViewPage extends StatefulWidget {
  const WebViewHandoffWebViewPage({
    required this.url,
    this.useAppOwnedSpan = false,
    super.key,
  });

  final Uri url;

  /// Whether this page owns the span whose trace context is propagated.
  final bool useAppOwnedSpan;

  @override
  State<WebViewHandoffWebViewPage> createState() =>
      _WebViewHandoffWebViewPageState();
}

class _WebViewHandoffWebViewPageState extends State<WebViewHandoffWebViewPage> {
  late final WebViewController _controller;
  late final FaroWebViewBridge _bridge;
  Span? _appSpan;
  String _traceparent = '';
  String _status = 'Opening WebView\u2026';
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();

    _bridge = FaroWebViewBridge();

    if (widget.useAppOwnedSpan) {
      // This span lives for as long as the WebView does, which keeps the
      // propagated traceparent stable across reloads.
      _appSpan = Faro().startSpanManual(
        'webview.lifecycle',
        attributes: {'component': 'webview', 'url.full': widget.url.toString()},
      );
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // The React app calls window.HandoffBridge.postMessage(json) to
      // send login results back to Flutter.
      ..addJavaScriptChannel(
        'HandoffBridge',
        onMessageReceived: _handleBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _status = 'Loading\u2026';
              _hasLoadError = false;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _status = 'Loaded');
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame != true) return;
            setState(() {
              _status = 'Failed to load';
              _hasLoadError = true;
            });
          },
        ),
      );

    _loadInstrumentedUrl();
  }

  @override
  void dispose() {
    // Always close out the WebView span when the WebView is dismissed, so
    // its duration reflects the time the user spent in the WebView. The
    // bridge only ends spans it created itself, so an app-owned span has
    // to be ended here.
    final appSpan = _appSpan;
    if (appSpan != null) {
      appSpan.setStatus(SpanStatusCode.ok);
      appSpan.end();
    } else {
      _bridge.end();
    }
    super.dispose();
  }

  /// Decorates the URL with the trace and session parameters and loads it.
  ///
  /// Passing a null [Span] is the default behaviour: the bridge starts and
  /// owns a span of its own.
  void _loadInstrumentedUrl() {
    final instrumentedUrl = _bridge.instrumentedUrl(widget.url, span: _appSpan);
    _traceparent = instrumentedUrl.queryParameters['traceparent'] ?? '';
    _controller.loadRequest(instrumentedUrl);
  }

  void _reload() {
    _loadInstrumentedUrl();
    setState(() => _status = 'Reloading\u2026');
  }

  /// Extracts the trace ID from a `traceparent`, so it can be pasted into
  /// Tempo to compare traces across reloads.
  String _traceIdOf(String traceparent) {
    final parts = traceparent.split('-');
    return parts.length >= 2 ? parts[1] : 'n/a';
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      if (data['type'] == 'faro_session') {
        _bridge.linkChildSession(
          sessionId: data['session_id'] as String? ?? '',
          appName: data['app_name'] as String?,
        );
      } else if (data['type'] == 'login_result') {
        Navigator.of(context).pop(data);
      }
    } catch (_) {
      // Ignore malformed messages.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebView Login Demo')),
      body: Column(
        children: [
          Material(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: const Icon(Icons.link),
              isThreeLine: true,
              title: Text(
                widget.useAppOwnedSpan
                    ? 'React demo \u2014 app-owned span'
                    : 'React demo \u2014 SDK-owned span',
              ),
              subtitle: Text('$_status\ntrace: ${_traceIdOf(_traceparent)}'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload with a freshly instrumented URL',
                onPressed: _reload,
              ),
            ),
          ),
          Expanded(
            child: _hasLoadError
                ? const _LoadErrorHint()
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorHint extends StatelessWidget {
  const _LoadErrorHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Could not load the web app',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Make sure the React dev server is running:\n'
              '  cd example/webview_demo && yarn dev\n\n'
              'And verify that FARO_WEBVIEW_DEMO_URL in '
              'api-config.json points to the correct address\n'
              '(e.g. http://10.0.2.2:5173 for Android emulator).',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
