import 'package:faro_example/features/app_diagnostics/presentation/app_diagnostics_page_view_model.dart';
import 'package:faro_example/shared/presentation/widgets/demo_log_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo page for error and ANR scenarios.
class AppDiagnosticsPage extends ConsumerWidget {
  const AppDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(appDiagnosticsPageUiStateProvider);
    final actions = ref.watch(appDiagnosticsPageActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Diagnostics'),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'These demos intentionally trigger failure states. '
                          'Use them when you want to validate captured errors '
                          'or ANRs.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failure and ANR demos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The async error examples keep the page reachable while still '
                  'emitting uncaught failures through the app runtime.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DiagnosticsButton(
                      label: 'Throw Error',
                      icon: Icons.error,
                      isRunning: uiState.isRunning,
                      onPressed: actions.triggerUnhandledError,
                    ),
                    _DiagnosticsButton(
                      label: 'Throw Exception',
                      icon: Icons.warning,
                      isRunning: uiState.isRunning,
                      onPressed: actions.triggerUnhandledException,
                    ),
                    _DiagnosticsButton(
                      label: 'Simulate ANR (8s)',
                      icon: Icons.hourglass_bottom,
                      isRunning: uiState.isRunning,
                      onPressed: () => actions.simulateAnr(8),
                    ),
                    _DiagnosticsButton(
                      label: 'Simulate ANR (10s)',
                      icon: Icons.hourglass_top,
                      isRunning: uiState.isRunning,
                      onPressed: () => actions.simulateAnr(10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          DemoLogSection(
            entries: uiState.log,
            emptyMessage:
                'Run a diagnostic scenario to see the latest local notes.',
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsButton extends StatelessWidget {
  const _DiagnosticsButton({
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
