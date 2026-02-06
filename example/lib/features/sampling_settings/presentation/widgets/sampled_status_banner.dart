import 'package:flutter/material.dart';

/// Banner displaying whether the current session is sampled.
class SampledStatusBanner extends StatelessWidget {
  const SampledStatusBanner({super.key, required this.isSessionSampled});

  final bool isSessionSampled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSessionSampled ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSessionSampled ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSessionSampled ? Icons.check_circle : Icons.cancel,
            size: 32,
            color: isSessionSampled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSessionSampled ? 'Session Sampled' : 'Not Sampled',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSessionSampled
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSessionSampled
                      ? 'Telemetry is being collected'
                      : 'No telemetry collected this session',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSessionSampled
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
