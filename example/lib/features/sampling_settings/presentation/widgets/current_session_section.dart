import 'package:flutter/material.dart';

import '../sampling_settings_page_view_model.dart';
import 'restart_warning_banner.dart';
import 'sampled_status_banner.dart';

/// Card section displaying the current session's sampling status.
class CurrentSessionSection extends StatelessWidget {
  const CurrentSessionSection({super.key, required this.uiState});

  final SamplingSettingsPageUiState uiState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, size: 24),
                SizedBox(width: 8),
                Text(
                  'Current Session',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sampled status - prominent display
            SampledStatusBanner(
              isSessionSampled: uiState.isSessionSampled,
            ),
            const SizedBox(height: 12),
            Text(
              'Config: ${uiState.currentConfigDisplay}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            // Restart warning
            if (uiState.needsRestart) ...[
              const SizedBox(height: 12),
              RestartWarningBanner(
                selectedSetting: uiState.selectedSetting,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
