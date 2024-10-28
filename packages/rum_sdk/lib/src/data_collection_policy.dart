import 'dart:developer';

class DataCollectionPolicy {

  factory DataCollectionPolicy() {
    return _instance;
  }

  DataCollectionPolicy._();
  static final DataCollectionPolicy _instance = DataCollectionPolicy._();

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
