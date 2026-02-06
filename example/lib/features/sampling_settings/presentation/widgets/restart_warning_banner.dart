import 'package:flutter/material.dart';

import '../../models/sampling_setting.dart';

/// Banner warning that the app needs to restart to apply new sampling settings.
class RestartWarningBanner extends StatelessWidget {
  const RestartWarningBanner({super.key, required this.selectedSetting});

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
