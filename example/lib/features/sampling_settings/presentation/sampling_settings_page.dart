import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sampling_setting.dart';
import 'sampling_settings_page_view_model.dart';

/// Page for managing sampling settings in the example app.
///
/// Allows configuring the sampling strategy that will be passed to
/// FaroConfig on the next app start.
class SamplingSettingsPage extends ConsumerWidget {
  const SamplingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(samplingSettingsPageUiStateProvider);
    final actions = ref.watch(samplingSettingsPageActionsProvider);

    if (uiState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sampling Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sampling Settings'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          16.0 + MediaQuery.of(context).padding.bottom + 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CurrentSessionSection(uiState: uiState),
            const SizedBox(height: 24),
            _SamplingConfigSection(uiState: uiState, actions: actions),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Private Widgets
// =============================================================================

class _CurrentSessionSection extends StatelessWidget {
  const _CurrentSessionSection({required this.uiState});

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
            _SampledStatusBanner(isSessionSampled: uiState.isSessionSampled),
            const SizedBox(height: 12),
            Text(
              'Config: ${uiState.currentConfigDisplay}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            // Restart warning
            if (uiState.needsRestart) ...[
              const SizedBox(height: 12),
              _RestartWarningBanner(
                selectedSetting: uiState.selectedSetting,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SampledStatusBanner extends StatelessWidget {
  const _SampledStatusBanner({required this.isSessionSampled});

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

class _RestartWarningBanner extends StatelessWidget {
  const _RestartWarningBanner({required this.selectedSetting});

  final SamplingSetting selectedSetting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sampling setting changed! Restart the app to apply '
              '"${selectedSetting.displayName}".',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SamplingConfigSection extends StatelessWidget {
  const _SamplingConfigSection({
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
                      .map((setting) => _SamplingRadioTile(setting: setting)),

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
                      .map((setting) => _SamplingRadioTile(setting: setting)),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _InfoBanner(),
          ],
        ),
      ),
    );
  }
}

class _SamplingRadioTile extends StatelessWidget {
  const _SamplingRadioTile({required this.setting});

  final SamplingSetting setting;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<SamplingSetting>(
      title: Text(setting.displayName),
      subtitle: Text(
        setting.subtitle,
        style: const TextStyle(fontSize: 11),
      ),
      value: setting,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Restart the app to apply the new sampling configuration.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
