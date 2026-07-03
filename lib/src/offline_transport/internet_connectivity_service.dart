import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:faro/src/offline_transport/connectivity_checker.dart';

/// Signature of the DNS lookup used to probe actual internet access.
///
/// Matches the shape of [InternetAddress.lookup] and exists as an
/// injectable seam so tests can simulate slow, failing, or blocked DNS
/// resolution without real network access.
typedef InternetAddressLookup =
    Future<List<InternetAddress>> Function(String host);

/// Tracks whether the device currently has working internet access.
///
/// Combines connectivity_plus network-state changes with a DNS probe of
/// [internetConnectionCheckerUrl] to distinguish "connected to a network"
/// from "actually able to reach the internet".
class InternetConnectivityService {
  /// Creates the service and immediately starts monitoring connectivity.
  ///
  /// [addressLookup] performs the DNS probe; production wires
  /// [InternetAddress.lookup] via [InternetConnectivityServiceFactory], while
  /// tests inject a fake. [lookupTimeout] bounds each probe and defaults to
  /// [defaultLookupTimeout].
  InternetConnectivityService({
    required ConnectivityChecker connectivity,
    required String internetConnectionCheckerUrl,
    required InternetAddressLookup addressLookup,
    Duration lookupTimeout = defaultLookupTimeout,
  }) : _connectivity = connectivity,
       _internetConnectionCheckerUrl = internetConnectionCheckerUrl,
       _addressLookup = addressLookup,
       _lookupTimeout = lookupTimeout {
    _checkConnectivity();
    _monitorConnectivity();
  }

  /// Default upper bound for a single DNS probe. On some platforms an
  /// unbounded [InternetAddress.lookup] can hang for a long time, which
  /// would stall online/offline decisions.
  static const Duration defaultLookupTimeout = Duration(seconds: 5);

  final ConnectivityChecker _connectivity;
  final _connectivityController = StreamController<bool>.broadcast();
  final String _internetConnectionCheckerUrl;
  final InternetAddressLookup _addressLookup;
  final Duration _lookupTimeout;
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
    _connectivityChangedSubscription = _connectivity.onConnectivityChanged
        .listen(_handleConnectivityResults);
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _connectivityController.add(value);
    }
  }

  Future<void> _handleConnectivityResults(
    List<ConnectivityResult> results,
  ) async {
    final result = results.firstOrNull ?? ConnectivityResult.none;
    if (result == ConnectivityResult.none) {
      _setOnline(false);
    } else {
      _setOnline(await _isConnectedToInternet());
    }
  }

  /// Probes internet access via a DNS lookup, bounded by [_lookupTimeout].
  ///
  /// Any probe failure (timeout, socket error, or unexpected platform
  /// error) is treated as offline. This is deliberately conservative:
  /// while reported offline, payloads are cached on disk by
  /// `OfflineTransport` and flushed when connectivity returns, whereas a
  /// send attempted while actually offline is dropped by `FaroTransport`
  /// without retry. A false "offline" therefore only costs disk usage,
  /// while a false "online" risks permanent data loss.
  Future<bool> _isConnectedToInternet() async {
    try {
      final result = await _addressLookup(
        _internetConnectionCheckerUrl,
      ).timeout(_lookupTimeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on TimeoutException catch (_) {
      return false;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      // DNS probes can fail in unexpected ways (blocked resolvers,
      // platform errors). Never let a probe error escape and never
      // report online without a successful probe.
      return false;
    }
  }
}

class InternetConnectivityServiceFactory {
  InternetConnectivityService create({String? internetConnectionCheckerUrl}) {
    final checkerUrl = internetConnectionCheckerUrl ?? 'one.one.one.one';
    return InternetConnectivityService(
      connectivity: ConnectivityCheckerFactory().create(),
      internetConnectionCheckerUrl: checkerUrl,
      addressLookup: InternetAddress.lookup,
    );
  }
}
