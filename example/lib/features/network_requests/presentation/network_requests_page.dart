import 'package:faro_example/features/network_requests/presentation/network_requests_page_view_model.dart';
import 'package:faro_example/shared/presentation/widgets/demo_log_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo page for instrumented HTTP requests.
class NetworkRequestsPage extends ConsumerWidget {
  const NetworkRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(networkRequestsPageUiStateProvider);
    final actions = ref.watch(networkRequestsPageActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Requests'),
        actions: [
          TextButton(
            onPressed: actions.clearLog,
            child: const Text('Clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'HTTP tracking demos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'These requests are routed through the Faro HTTP overrides. '
                  'Use the success and failure variants to compare captured '
                  'telemetry.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RequestButton(
                      label: 'POST Success',
                      icon: Icons.upload,
                      isRunning: uiState.isRunning,
                      onPressed: actions.sendPostSuccess,
                    ),
                    _RequestButton(
                      label: 'POST Failure',
                      icon: Icons.upload_file,
                      isRunning: uiState.isRunning,
                      onPressed: actions.sendPostFailure,
                    ),
                    _RequestButton(
                      label: 'GET Success',
                      icon: Icons.download,
                      isRunning: uiState.isRunning,
                      onPressed: actions.sendGetSuccess,
                    ),
                    _RequestButton(
                      label: 'GET Failure',
                      icon: Icons.download_for_offline,
                      isRunning: uiState.isRunning,
                      onPressed: actions.sendGetFailure,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          DemoLogSection(
            entries: uiState.log,
            emptyMessage: 'Run a request to see the latest result.',
          ),
        ],
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  const _RequestButton({
    required this.label,
    required this.icon,
    required this.isRunning,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isRunning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isRunning ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
