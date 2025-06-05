import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

class DataCollectionPolicy {
  DataCollectionPolicy({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences {
    _initialize();
  }

  final SharedPreferences _sharedPreferences;
  static const String _enableDataCollectionKey = 'faro_enable_data_collection';
  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;

  Future<void> enable() async {
    log('Enabling faro telemetry collection');
    _isEnabled = true;
    await _persistSetting();
  }

  Future<void> disable() async {
    log('Disabling faro telemetry collection');
    _isEnabled = false;
    await _persistSetting();
  }

  void _initialize() {
    _isEnabled = _sharedPreferences.getBool(_enableDataCollectionKey) ?? true;
  }

  Future<void> _persistSetting() async {
    try {
      await _sharedPreferences.setBool(_enableDataCollectionKey, _isEnabled);
      log('Data collection setting persisted: $_isEnabled');
    } catch (error) {
      log('Failed to persist data collection setting: $error');
    }
  }
}

class DataCollectionPolicyFactory {
  Future<DataCollectionPolicy> create() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    return DataCollectionPolicy(sharedPreferences: sharedPreferences);
  }
}
