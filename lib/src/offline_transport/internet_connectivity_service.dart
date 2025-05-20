import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:faro/src/offline_transport/connectivity_checker.dart';
import 'package:faro/src/offline_transport/network_reachability_checker/network_reachability_checker.dart';

class InternetConnectivityService {
  InternetConnectivityService({
    required ConnectivityChecker connectivity,
    required String internetConnectionCheckerUrl,
    required NetworkReachabilityChecker networkReachabilityChecker,
  })  : _connectivity = connectivity,
        _networkReachabilityChecker = networkReachabilityChecker,
        _internetConnectionCheckerUrl = internetConnectionCheckerUrl {
    _checkConnectivity();
    _monitorConnectivity();
  }

  final ConnectivityChecker _connectivity;
  final NetworkReachabilityChecker _networkReachabilityChecker;
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
    return _networkReachabilityChecker.isConnectedToInternet(
      _internetConnectionCheckerUrl,
    );
  }
}

class InternetConnectivityServiceFactory {
  InternetConnectivityService create({
    String? internetConnectionCheckerUrl,
  }) {
    final checkerUrl = internetConnectionCheckerUrl ?? 'one.one.one.one';
    return InternetConnectivityService(
      connectivity: ConnectivityCheckerFactory().create(),
      networkReachabilityChecker: NetworkReachabilityCheckerFactory().create(),
      internetConnectionCheckerUrl: checkerUrl,
    );
  }
}
