import 'package:flutter/material.dart';

/// A lightweight page that auto-pops after a configurable delay.
///
/// Used by the navigation scenario to trigger a route push/pop
/// that the [FaroNavigationObserver] reports as activity.
class AutoPopPage extends StatefulWidget {
  const AutoPopPage({
    super.key,
    this.title = 'Navigation Test',
    this.description = 'Simulating navigation activity.',
    this.autoPopDelay = const Duration(seconds: 2),
  });

  final String title;
  final String description;
  final Duration autoPopDelay;

  @override
  State<AutoPopPage> createState() => _AutoPopPageState();
}

class _AutoPopPageState extends State<AutoPopPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.autoPopDelay, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final delayMs = widget.autoPopDelay.inMilliseconds;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '${widget.description}\n'
              'Auto-returning in $delayMs ms.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
