import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter/material.dart';

/// Reusable log view for example pages.
class DemoLogSection extends StatelessWidget {
  const DemoLogSection({
    required this.entries,
    required this.emptyMessage,
    super.key,
  });

  final List<DemoLogEntry> entries;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: Colors.grey.shade100,
        child: entries.isEmpty
            ? Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return _DemoLogEntryRow(entry: entries[index]);
                },
              ),
      ),
    );
  }
}

class _DemoLogEntryRow extends StatelessWidget {
  const _DemoLogEntryRow({required this.entry});

  final DemoLogEntry entry;

  Color _resolveColor() {
    return switch (entry.tone) {
      DemoLogTone.info => Colors.blueGrey,
      DemoLogTone.success => Colors.green.shade700,
      DemoLogTone.warning => Colors.orange.shade800,
      DemoLogTone.error => Colors.red,
      DemoLogTone.highlight => Colors.indigo,
      DemoLogTone.neutral => Colors.black87,
    };
  }

  FontWeight _resolveWeight() {
    return switch (entry.tone) {
      DemoLogTone.highlight => FontWeight.bold,
      _ => FontWeight.normal,
    };
  }

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
                color: _resolveColor(),
                fontWeight: _resolveWeight(),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
