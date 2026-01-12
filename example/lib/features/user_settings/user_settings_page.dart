import 'package:faro/faro.dart';
import 'package:flutter/material.dart';

import 'initial_user_setting.dart';
import 'user_settings_service.dart';

/// Page for managing user settings in the example app.
///
/// Allows setting the current session user and configuring FaroConfig
/// settings for initial user and persistence.
class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final _service = UserSettingsService.instance;

  String _currentUserDisplay = 'Not set';
  InitialUserSetting _initialUserSetting = InitialUserSetting.none;
  bool _persistUser = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _service.init();
    setState(() {
      _initialUserSetting = _service.initialUserSetting;
      _persistUser = _service.persistUser;
      _currentUserDisplay = _service.getCurrentUserDisplay();
      _isLoading = false;
    });
  }

  Future<void> _setInitialUserSetting(InitialUserSetting setting) async {
    await _service.setInitialUserSetting(setting);
    setState(() {
      _initialUserSetting = setting;
    });
  }

  Future<void> _setPersistUser(bool value) async {
    await _service.setPersistUser(value);
    setState(() {
      _persistUser = value;
    });
  }

  Future<void> _setUser(FaroUser user) async {
    await Faro().setUser(user);
    setState(() {
      _currentUserDisplay = _service.getCurrentUserDisplay();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Settings'),
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
            _buildCurrentUserSection(),
            const SizedBox(height: 24),
            _buildFaroConfigSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUserSection() {
    final sessionPersistUser = _service.currentSessionPersistUser;
    final persistUserMismatch = _service.persistUserNeedsRestart;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, size: 24),
                SizedBox(width: 8),
                Text(
                  'Current Session User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currentUserDisplay,
              style: TextStyle(
                fontSize: 16,
                color: _currentUserDisplay == 'Not set'
                    ? Colors.grey
                    : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Session persistUser: $sessionPersistUser',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (persistUserMismatch) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 20, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Persist User setting changed! Current session uses '
                        '"$sessionPersistUser" but saved setting is '
                        '"$_persistUser". Restart to apply.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Set user at runtime (affects current session):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('john.doe'),
                  onPressed: () => _setUser(const FaroUser(
                    id: 'user-123',
                    username: 'john.doe',
                    email: 'john.doe@example.com',
                  )),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('jane.smith'),
                  onPressed: () => _setUser(const FaroUser(
                    id: 'user-456',
                    username: 'jane.smith',
                    email: 'jane.smith@example.com',
                  )),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_remove, size: 18),
                  label: const Text('Clear User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _setUser(const FaroUser.cleared()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaroConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FaroConfig Settings',
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
              'These settings are passed to FaroConfig on app start. '
              'Changes require app restart to take effect.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Persist User Toggle
            SwitchListTile(
              title: const Text('Persist User'),
              subtitle: Text(
                _persistUser
                    ? 'User will be saved and restored on app restart'
                    : 'User will not be persisted',
                style: const TextStyle(fontSize: 11),
              ),
              value: _persistUser,
              onChanged: _setPersistUser,
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(),
            const SizedBox(height: 8),

            // Initial User Setting
            const Text(
              'Initial User',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...InitialUserSetting.values.map((setting) {
              return RadioListTile<InitialUserSetting>(
                title: Text(setting.displayName),
                subtitle: Text(
                  setting.subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                value: setting,
                groupValue: _initialUserSetting,
                onChanged: (value) {
                  if (value != null) {
                    _setInitialUserSetting(value);
                  }
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Restart the app to apply these settings.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
