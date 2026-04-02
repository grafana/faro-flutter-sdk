import 'dart:convert';

import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the React demo inside a WebView.
///
/// Uses [FaroWebViewBridge] to create a `WebView` span and inject
/// `traceparent` and `session.parent_*` query parameters into the URL
/// so the web app can continue the Flutter trace and identify its
/// originating session.
///
/// A `HandoffBridge` JavaScript channel is registered so the React app
/// can send messages back. Supported message types:
/// - `faro_session` — the web app's Faro session ID, used to push a
///   `session.linked` event with `session.child_*` attributes.
/// - `login_result` — login result data; auto-pops the page.
class WebViewHandoffWebViewPage extends StatefulWidget {
  const WebViewHandoffWebViewPage({
    required this.url,
    super.key,
  });

  final Uri url;

  @override
  State<WebViewHandoffWebViewPage> createState() =>
      _WebViewHandoffWebViewPageState();
}

class _WebViewHandoffWebViewPageState extends State<WebViewHandoffWebViewPage> {
  late final WebViewController _controller;
  late final FaroWebViewBridge _bridge;
  String _status = 'Opening WebView\u2026';
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();

    // Starts a WebView span and appends traceparent + session correlation
    // query params so the web app can continue the trace and link sessions.
    _bridge = FaroWebViewBridge();
    final instrumentedUrl = _bridge.instrumentedUrl(widget.url);

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
      )
      ..loadRequest(instrumentedUrl);
  }

  @override
  void dispose() {
    // End the WebView span started by instrumentedUrl(). Always call
    // bridge.end() when the WebView is dismissed so the span duration
    // accurately reflects the time the user spent in the WebView.
    _bridge.end();
    super.dispose();
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
      appBar: AppBar(
        title: const Text('WebView Login Demo'),
      ),
      body: Column(
        children: [
          Material(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: const Icon(Icons.link),
              title: const Text('React demo app'),
              subtitle: Text(_status),
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
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load the web app',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Make sure the React dev server is running:\n'
              '  cd example/webview_demo && npm run dev\n\n'
              'And verify that FARO_WEBVIEW_DEMO_URL in '
              'api-config.json points to the correct address\n'
              '(e.g. http://10.0.2.2:5173 for Android emulator).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
