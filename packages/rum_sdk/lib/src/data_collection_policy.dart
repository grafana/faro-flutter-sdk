import 'dart:developer';

class DataCollectionPolicy {
  static final DataCollectionPolicy _instance = DataCollectionPolicy._();

  DataCollectionPolicy._();

  factory DataCollectionPolicy() {
    return _instance;
  }

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  void enable() {
    log('Enabling data collection');
    _isEnabled = true;
  }

  void disable() {
    log('Disabling data collection');
    _isEnabled = false;
  }
}
