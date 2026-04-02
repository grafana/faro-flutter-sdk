import 'package:faro_example/features/webview_handoff/presentation/webview_handoff_page_view_model.dart';
import 'package:faro_example/features/webview_handoff/presentation/webview_handoff_webview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Landing page for the WebView tracing demo. Shows setup instructions
/// if `FARO_WEBVIEW_DEMO_URL` is not configured, and a button to open
/// the React demo in a WebView. Login results from the web app are
/// shown as a [SnackBar] when the WebView closes.
class WebViewHandoffPage extends ConsumerWidget {
  const WebViewHandoffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(webViewHandoffPageUiStateProvider);
    final actions = ref.watch(webViewHandoffPageActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebView Tracing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _OverviewCard(),
          if (!uiState.isConfigured) ...[
            const SizedBox(height: 12),
            const _MissingConfigCard(),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: uiState.isConfigured
                ? () => _openWebView(context, actions)
                : null,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open React demo in WebView'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWebView(
    BuildContext context,
    WebViewHandoffPageActions actions,
  ) async {
    final url = actions.getBaseUrl();
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => WebViewHandoffWebViewPage(url: url),
      ),
    );

    if (!context.mounted) return;

    if (result != null) {
      final ok = result['ok'] == true;
      final message = result['message'] as String? ??
          (ok ? 'Login successful' : 'Login failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cross-boundary tracing',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Opens a React app in a WebView and passes the current '
              'traceparent so the web app can continue the native trace. '
              'Use Grafana Tempo to verify the Flutter and React spans '
              'share the same trace ID.',
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingConfigCard extends StatelessWidget {
  const _MissingConfigCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Text(
                  'Setup required',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Start the React demo:\n'
              '   cd example/webview_demo && npm run dev\n\n'
              '2. Add FARO_WEBVIEW_DEMO_URL to api-config.json:\n'
              '   Android emulator: http://10.0.2.2:5173\n'
              '   iOS simulator: http://localhost:5173',
            ),
          ],
        ),
      ),
    );
  }
}
