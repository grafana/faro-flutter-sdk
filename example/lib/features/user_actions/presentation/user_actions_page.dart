import 'dart:async';

import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/action_log_entry.dart';
import 'user_actions_page_view_model.dart';

/// Demo page for the User Actions feature.
///
/// Provides multiple scenarios to exercise different action lifecycles
/// and displays a live log of state transitions.
class UserActionsPage extends ConsumerStatefulWidget {
  const UserActionsPage({super.key});

  @override
  ConsumerState<UserActionsPage> createState() => _UserActionsPageState();
}

class _UserActionsPageState extends ConsumerState<UserActionsPage> {
  Timer? _pollTimer;

  String? _actionName;
  UserActionState? _actionState;

  @override
  void initState() {
    super.initState();
    _syncBanner();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _syncBanner(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _syncBanner() {
    final handle = Faro().getActiveUserAction();
    final newName = handle?.name;
    final newState = handle?.getState();
    if (newName != _actionName || newState != _actionState) {
      setState(() {
        _actionName = newName;
        _actionState = newState;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(userActionsPageUiStateProvider);
    final actions = ref.watch(userActionsPageActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Actions'),
        actions: [
          TextButton(onPressed: actions.clearLog, child: const Text('Clear')),
        ],
      ),
      body: Column(
        children: [
          _StatusBanner(actionName: _actionName, actionState: _actionState),
          _ScenariosSection(
            isRunning: uiState.isRunning,
            actions: actions,
            onTapped: _syncBanner,
          ),
          const Divider(height: 1),
          _LogSection(log: uiState.log),
        ],
      ),
    );
  }
}

// =============================================================================
// Status Banner
// =============================================================================

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.actionName, required this.actionState});

  final String? actionName;
  final UserActionState? actionState;

  Color get _color {
    return switch (actionState) {
      UserActionState.started => Colors.green,
      UserActionState.halted => Colors.orange,
      UserActionState.ended => Colors.blue,
      UserActionState.cancelled => Colors.red,
      null => Colors.grey,
    };
  }

  String get _label {
    if (actionName == null || actionState == null) {
      return 'No active action';
    }
    return '$actionName (${actionState!.name})';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: _color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _label,
              style: TextStyle(fontWeight: FontWeight.bold, color: _color),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Scenarios Section
// =============================================================================

class _ScenariosSection extends StatelessWidget {
  const _ScenariosSection({
    required this.isRunning,
    required this.actions,
    required this.onTapped,
  });

  final bool isRunning;
  final UserActionsPageActions actions;

  /// Called immediately after a scenario is fired so the banner
  /// can pick up the freshly-created action.
  final VoidCallback onTapped;

  void _showScenarioInfo(
    BuildContext context, {
    required String title,
    required String details,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(details),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Test Scenarios',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _ScenarioRow(
                label: 'No follow-up (cancel)',
                icon: Icons.hourglass_empty,
                onPressed: () {
                  actions.runIdleCancelScenario();
                  onTapped();
                },
                onInfoPressed: () {
                  _showScenarioInfo(
                    context,
                    title: 'No follow-up (cancel)',
                    details:
                        '- Starts one user action.\n'
                        '- Emits no follow-up activity.\n'
                        '- After follow-up timeout, expected: '
                        'started -> cancelled.\n'
                        '- Useful to verify "no activity" cancellation.',
                  );
                },
                isRunning: isRunning,
              ),
              const SizedBox(height: 8),
              _ScenarioRow(
                label: 'Concurrent start guard',
                icon: Icons.lock_outline,
                onPressed: () {
                  actions.runConcurrentStartScenario(Navigator.of(context));
                  onTapped();
                },
                onInfoPressed: () {
                  _showScenarioInfo(
                    context,
                    title: 'Concurrent start guard',
                    details:
                        '- Starts one primary user action.\n'
                        '- Immediately tries to start a second action.\n'
                        '- Expected while primary is active: second start returns null.\n'
                        '- Uses a short navigation pulse so primary ends (not cancelled).\n'
                        '- Then a new action is started and gets the same navigation pulse.\n'
                        '- Expected final states: primary=ended, after-release=ended.',
                  );
                },
                isRunning: isRunning,
              ),
              const SizedBox(height: 8),
              _ScenarioRow(
                label: 'Fast view push+pop',
                icon: Icons.route,
                onPressed: () {
                  actions.runFastNavigationScenario(Navigator.of(context));
                  onTapped();
                },
                onInfoPressed: () {
                  _showScenarioInfo(
                    context,
                    title: 'Fast view push+pop',
                    details:
                        '- Starts one user action.\n'
                        '- Triggers quick route push and pop.\n'
                        '- Navigation observer emits activity signals.\n'
                        '- Expected: started -> ended (no halted).',
                  );
                },
                isRunning: isRunning,
              ),
              const SizedBox(height: 8),
              _ScenarioRow(
                label: 'Single HTTP (halt)',
                icon: Icons.cloud_download,
                onPressed: () {
                  actions.runSingleHttpScenario();
                  onTapped();
                },
                onInfoPressed: () {
                  _showScenarioInfo(
                    context,
                    title: 'Single HTTP (halt)',
                    details:
                        '- Starts one user action.\n'
                        '- Sends one request to /delay/3.\n'
                        '- Pending operation causes halt after follow-up.\n'
                        '- Expected: started -> halted -> ended.',
                  );
                },
                isRunning: isRunning,
              ),
              const SizedBox(height: 8),
              _ScenarioRow(
                label: 'Parallel HTTP (1/2/3/6s)',
                icon: Icons.cloud_sync,
                onPressed: () {
                  actions.runParallelHttpScenario();
                  onTapped();
                },
                onInfoPressed: () {
                  _showScenarioInfo(
                    context,
                    title: 'Parallel HTTP (1/2/3/6s)',
                    details:
                        '- Starts one user action.\n'
                        '- Wraps the whole flow in custom span '
                        '`ua.parallel_http.parent_span`.\n'
                        '- Fires 4 requests in parallel (1s, 2s, 3s, 6s).\n'
                        '- Creates `ua.parallel_http.late_span` once action '
                        'is halted.\n'
                        '- Action should stay halted until the 6s request ends.\n'
                        '- Expected: parent span is linked; late span is not.',
                  );
                },
                isRunning: isRunning,
              ),
              const SizedBox(height: 8),
              _ScenarioRow(
                label: 'Mixed timing window',
                icon: Icons.layers,
                onPressed: () {
                  actions.runMixedTimingScenario(Navigator.of(context));
                  onTapped();
                },
                onInfoPressed: () {
                  _showScenarioInfo(
                    context,
                    title: 'Mixed timing window',
                    details:
                        '- Emits these telemetry items immediately:\n'
                        '  event=`ua.pre_halt.event`, '
                        'log=`ua.pre_halt.log`, '
                        'error=`ua.pre_halt.error`.\n'
                        '- Starts long HTTP + fast view transition.\n'
                        '- After ~250ms emits:\n'
                        '  event=`ua.post_halt.event`, '
                        'log=`ua.post_halt.log`, '
                        'error=`ua.post_halt.error`.\n'
                        '- Meaning of pre/post: "pre_halt" is before halted state, '
                        '"post_halt" is after halted state.\n'
                        '- Query by runId and compare which items got action context.',
                  );
                },
                isRunning: isRunning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.onInfoPressed,
    required this.isRunning,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback onInfoPressed;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScenarioButton(
            label: label,
            icon: icon,
            onPressed: onPressed,
            isRunning: isRunning,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onInfoPressed,
          tooltip: 'What to expect',
          icon: const Icon(Icons.info_outline),
        ),
      ],
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({
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

// =============================================================================
// Log Section
// =============================================================================

class _LogSection extends StatelessWidget {
  const _LogSection({required this.log});

  final List<ActionLogEntry> log;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: Colors.grey.shade100,
        child:
            log.isEmpty
                ? const Center(
                  child: Text(
                    'Run a scenario to see the action lifecycle log',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: log.length,
                  itemBuilder: (_, index) => _LogEntryRow(entry: log[index]),
                ),
      ),
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.entry});

  final ActionLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    if (entry.isError) {
      textColor = Colors.red;
    } else if (entry.isHighlight) {
      textColor = Colors.indigo;
    } else {
      textColor = Colors.black87;
    }

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
                color: textColor,
                fontWeight:
                    entry.isHighlight ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
