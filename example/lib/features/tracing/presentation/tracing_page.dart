import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/span_log_entry.dart';
import 'tracing_page_view_model.dart';

/// Page for testing span/trace functionality in the example app.
///
/// Demonstrates creating spans with various configurations and verifying
/// they are correctly sent to the Faro backend.
class TracingPage extends ConsumerWidget {
  const TracingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(tracingPageUiStateProvider);
    final actions = ref.watch(tracingPageActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracing / Spans'),
        actions: [
          TextButton(
            onPressed: actions.clearLog,
            child: const Text('Clear Logs'),
          ),
        ],
      ),
      body: Column(
        children: [
          _ButtonsSection(uiState: uiState, actions: actions),
          const Divider(height: 1),
          _LogSection(spanLog: uiState.spanLog),
        ],
      ),
    );
  }
}

// =============================================================================
// Private Widgets
// =============================================================================

class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection({
    required this.uiState,
    required this.actions,
  });

  final TracingPageUiState uiState;
  final TracingPageActions actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Test Span Operations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create and test spans with different configurations. '
            'Check your Faro backend to verify spans are received correctly.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SpanButton(
                label: 'Simple Span',
                icon: Icons.play_arrow,
                onPressed: actions.runSimpleSpan,
                isRunning: uiState.isRunning,
              ),
              _SpanButton(
                label: 'String Attrs',
                icon: Icons.text_fields,
                onPressed: actions.runSpanWithStringAttributes,
                isRunning: uiState.isRunning,
              ),
              _SpanButton(
                label: 'Typed Attrs',
                icon: Icons.numbers,
                onPressed: actions.runSpanWithTypedAttributes,
                isRunning: uiState.isRunning,
              ),
              _SpanButton(
                label: 'Manual Span',
                icon: Icons.pan_tool,
                onPressed: actions.runManualSpan,
                isRunning: uiState.isRunning,
              ),
              _SpanButton(
                label: 'Nested Spans',
                icon: Icons.account_tree,
                onPressed: actions.runNestedSpans,
                isRunning: uiState.isRunning,
              ),
              _SpanButton(
                label: 'With Error',
                icon: Icons.error_outline,
                onPressed: actions.runSpanWithError,
                isRunning: uiState.isRunning,
              ),
              _SpanButton(
                label: 'No Parent',
                icon: Icons.link_off,
                onPressed: actions.runSpanWithNoParent,
                isRunning: uiState.isRunning,
              ),
              _SpanButton(
                label: 'Context Scope',
                icon: Icons.timer,
                onPressed: actions.runContextScopeDemo,
                isRunning: uiState.isRunning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpanButton extends StatelessWidget {
  const _SpanButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isRunning,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isRunning ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection({required this.spanLog});

  final List<SpanLogEntry> spanLog;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: Colors.grey.shade100,
        child: spanLog.isEmpty
            ? const Center(
                child: Text(
                  'Run a span operation to see the log',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: spanLog.length,
                itemBuilder: (context, index) {
                  final entry = spanLog[index];
                  return _LogEntryRow(entry: entry);
                },
              ),
      ),
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.entry});

  final SpanLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
            '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
            '${entry.timestamp.second.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontSize: 12,
                color: entry.isError ? Colors.red : Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
