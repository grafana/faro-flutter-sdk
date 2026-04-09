import 'package:faro_example/features/custom_telemetry/presentation/custom_telemetry_page_view_model.dart';
import 'package:faro_example/shared/presentation/widgets/demo_log_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo page for sending custom Faro telemetry items.
class CustomTelemetryPage extends ConsumerWidget {
  const CustomTelemetryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(customTelemetryPageUiStateProvider);
    final actions = ref.watch(customTelemetryPageActionsProvider);

    final dataCollectionColor =
        uiState.isDataCollectionEnabled ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Telemetry'),
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
                    color: dataCollectionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: dataCollectionColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.radar, color: dataCollectionColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          uiState.isDataCollectionEnabled
                              ? 'Data collection is enabled.'
                              : 'Data collection is disabled.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dataCollectionColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Telemetry Signals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use these controls to send custom logs, events, and '
                  'measurements without mixing them into the main feature list.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TelemetryButton(
                      label: 'Warn Log',
                      icon: Icons.warning_amber,
                      onPressed: actions.emitWarnLog,
                    ),
                    _TelemetryButton(
                      label: 'Info Log',
                      icon: Icons.info_outline,
                      onPressed: actions.emitInfoLog,
                    ),
                    _TelemetryButton(
                      label: 'Error Log',
                      icon: Icons.error_outline,
                      onPressed: actions.emitErrorLog,
                    ),
                    _TelemetryButton(
                      label: 'Debug Log',
                      icon: Icons.bug_report,
                      onPressed: actions.emitDebugLog,
                    ),
                    _TelemetryButton(
                      label: 'Trace Log',
                      icon: Icons.route,
                      onPressed: actions.emitTraceLog,
                    ),
                    _TelemetryButton(
                      label: 'Custom Measurement',
                      icon: Icons.speed,
                      onPressed: actions.emitMeasurement,
                    ),
                    _TelemetryButton(
                      label: 'Custom Event',
                      icon: Icons.event,
                      onPressed: actions.emitEvent,
                    ),
                    _TelemetryButton(
                      label: uiState.isDataCollectionEnabled
                          ? 'Disable Data Collection'
                          : 'Enable Data Collection',
                      icon: uiState.isDataCollectionEnabled
                          ? Icons.toggle_on
                          : Icons.toggle_off,
                      onPressed: actions.toggleDataCollection,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          DemoLogSection(
            entries: uiState.log,
            emptyMessage: 'Send custom telemetry to see the local action log.',
          ),
        ],
      ),
    );
  }
}

class _TelemetryButton extends StatelessWidget {
  const _TelemetryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
