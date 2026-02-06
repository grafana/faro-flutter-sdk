import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sampling_settings_page_view_model.dart';
import 'widgets/current_session_section.dart';
import 'widgets/sampling_config_section.dart';

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
            CurrentSessionSection(uiState: uiState),
            const SizedBox(height: 24),
            SamplingConfigSection(uiState: uiState, actions: actions),
          ],
        ),
      ),
    );
  }
}
