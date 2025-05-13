import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:faro/src/offline_transport/connectivity_checker.dart';
import 'package:faro/src/offline_transport/native_connectivity_check_stub.dart'
    if (dart.library.io) 'native_connectivity_check.dart';
import 'package:flutter/foundation.dart';

class InternetConnectivityService {
  InternetConnectivityService({
    required ConnectivityChecker connectivity,
    required String internetConnectionCheckerUrl,
  })  : _connectivity = connectivity,
        _internetConnectionCheckerUrl = internetConnectionCheckerUrl {
    _checkConnectivity();
    _monitorConnectivity();
  }

  final ConnectivityChecker _connectivity;
  final _connectivityController = StreamController<bool>.broadcast();
  final String _internetConnectionCheckerUrl;
  StreamSubscription<List<ConnectivityResult>>?
      _connectivityChangedSubscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged {
    // Emit current value immediately for new subscribers
    Future(() => _connectivityController.add(_isOnline));
    return _connectivityController.stream.distinct();
  }

  void dispose() {
    _connectivityChangedSubscription?.cancel();
    _connectivityController.close();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    await _handleConnectivityResults(results);
  }

  void _monitorConnectivity() {
    _connectivityChangedSubscription?.cancel();
    _connectivityChangedSubscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityResults);
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _connectivityController.add(value);
    }
  }

  Future<void> _handleConnectivityResults(
      List<ConnectivityResult> results) async {
    final result = results.firstOrNull ?? ConnectivityResult.none;
    if (result == ConnectivityResult.none) {
      _setOnline(false);
    } else {
      _setOnline(await _isConnectedToInternet());
    }
  }

  Future<bool> _isConnectedToInternet() async {
    try {
      if (kIsWeb) {
        final connectivityResult = await Connectivity().checkConnectivity();
        return !connectivityResult.contains(ConnectivityResult.none);
      } else {
        return await performNativeInternetCheck(_internetConnectionCheckerUrl);
      }
    } catch (_) {
      return false;
    }
  }
}

class InternetConnectivityServiceFactory {
  InternetConnectivityService create({
    String? internetConnectionCheckerUrl,
  }) {
    final checkerUrl = internetConnectionCheckerUrl ?? 'one.one.one.one';
    return InternetConnectivityService(
      connectivity: ConnectivityCheckerFactory().create(),
      internetConnectionCheckerUrl: checkerUrl,
    );
  }
}
