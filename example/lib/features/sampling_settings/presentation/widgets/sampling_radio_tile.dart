import 'package:flutter/material.dart';

import '../../models/sampling_setting.dart';

/// Radio list tile for selecting a [SamplingSetting].
class SamplingRadioTile extends StatelessWidget {
  const SamplingRadioTile({super.key, required this.setting});

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
