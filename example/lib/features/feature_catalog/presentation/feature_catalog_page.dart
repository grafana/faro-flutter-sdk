import 'package:faro/faro.dart';
import 'package:faro_example/features/user_settings/user_settings_service.dart';
import 'package:flutter/material.dart';

/// Landing page that groups the example app into dedicated demo areas.
class FeatureCatalogPage extends StatefulWidget {
  const FeatureCatalogPage({super.key});

  @override
  State<FeatureCatalogPage> createState() => _FeatureCatalogPageState();
}

class _FeatureCatalogPageState extends State<FeatureCatalogPage> {
  final UserSettingsService _userSettingsService = UserSettingsService.instance;

  String _currentUserDisplay = 'Not set';

  bool get _isSessionSampled => Faro().isSampled;
  String get _samplingStatusDisplay =>
      _isSessionSampled ? 'Sampled' : 'Not sampled';

  @override
  void initState() {
    super.initState();
    _refreshSummaries();
  }

  void _refreshSummaries() {
    setState(() {
      _currentUserDisplay = _userSettingsService.getCurrentUserDisplay();
    });
  }

  Future<void> _openFeature(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (!mounted) {
      return;
    }
    _refreshSummaries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Features'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Browse focused demo pages instead of one long action list. '
            'Each feature groups related examples and explains what to try.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Configure SDK',
            subtitle: 'Set up user and sampling behavior for the current app.',
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.person,
            title: 'User Settings',
            subtitle: 'Current user: $_currentUserDisplay',
            onTap: () => _openFeature('/user-settings'),
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.analytics,
            iconColor: _isSessionSampled ? Colors.green : Colors.grey,
            title: 'Sampling Settings',
            subtitle: 'Current session: $_samplingStatusDisplay',
            onTap: () => _openFeature('/sampling-settings'),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Explore Telemetry',
            subtitle: 'Group logs, requests, spans, and action demos by theme.',
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.podcasts,
            title: 'Custom Telemetry',
            subtitle:
                'Send logs, measurements, events, and toggle data collection.',
            onTap: () => _openFeature('/custom-telemetry'),
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.http,
            title: 'Network Requests',
            subtitle: 'Send instrumented GET and POST requests.',
            onTap: () => _openFeature('/network-requests'),
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.timeline,
            title: 'Tracing / Spans',
            subtitle: 'Create and inspect span scenarios.',
            onTap: () => _openFeature('/tracing'),
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.language,
            title: 'WebView Tracing',
            subtitle:
                'Cross-boundary tracing between Flutter and a React WebView.',
            onTap: () => _openFeature('/webview-handoff'),
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.touch_app,
            title: 'User Actions',
            subtitle: 'Run lifecycle scenarios and inspect action state.',
            onTap: () => _openFeature('/user-actions'),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Stress Runtime Behavior',
            subtitle: 'Trigger failure and ANR scenarios in one place.',
          ),
          const SizedBox(height: 8),
          _FeatureCard(
            icon: Icons.warning_amber,
            title: 'App Diagnostics',
            subtitle: 'Throw errors, throw exceptions, and simulate ANRs.',
            onTap: () => _openFeature('/app-diagnostics'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
