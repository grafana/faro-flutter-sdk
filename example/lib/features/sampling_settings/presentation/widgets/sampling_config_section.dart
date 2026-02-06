import 'package:flutter/material.dart';

import '../../models/sampling_setting.dart';
import '../sampling_settings_page_view_model.dart';
import 'info_banner.dart';
import 'sampling_radio_tile.dart';

/// Card section for configuring the sampling strategy.
class SamplingConfigSection extends StatelessWidget {
  const SamplingConfigSection({
    super.key,
    required this.uiState,
    required this.actions,
  });

  final SamplingSettingsPageUiState uiState;
  final SamplingSettingsPageActions actions;

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
                Icon(Icons.tune, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sampling Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a sampling strategy for the next app start. '
              'Changes require app restart to take effect.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Wrap all radio tiles in a single RadioGroup
            RadioGroup<SamplingSetting>(
              groupValue: uiState.selectedSetting,
              onChanged: (value) {
                if (value != null) {
                  actions.setSamplingSetting(value);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fixed Rate Options
                  const Text(
                    'Fixed Rate (SamplingRate)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...SamplingSetting.values
                      .where((s) => !s.isFunction)
                      .map(
                        (setting) => SamplingRadioTile(setting: setting),
                      ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Function-based Options
                  const Text(
                    'Dynamic (SamplingFunction)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tip: jane.smith has role=admin, john.doe has role=user',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ...SamplingSetting.values
                      .where((s) => s.isFunction)
                      .map(
                        (setting) => SamplingRadioTile(setting: setting),
                      ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const InfoBanner(),
          ],
        ),
      ),
    );
  }
}
