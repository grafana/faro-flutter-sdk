import 'dart:async';
import 'dart:developer';

import 'package:faro/src/device_info/platform_info_provider.dart';
import 'package:faro/src/models/device.dart';
import 'package:faro/src/models/network.dart';
import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device and network values that change while the app runs.
class DynamicDeviceState {
  const DynamicDeviceState({required this.device, required this.network});

  /// Reads the map the native side returns. Drops every value of the wrong
  /// type or range, so one bad field never costs the others.
  factory DynamicDeviceState.fromNative(Map<String, dynamic> native) {
    return DynamicDeviceState(
      device: Device(
        batteryLevel: _percent(native['batteryLevel']),
        isCharging: _bool(native['isCharging']),
        lowPowerMode: _bool(native['lowPowerMode']),
        thermalState: _oneOf(native['thermalState'], _thermalStates),
      ),
      network: Network(
        connectionType: _oneOf(native['connectionType'], _connectionTypes),
        connectionSubtype: _text(native['connectionSubtype']),
        carrierName: _text(native['carrierName']),
      ),
    );
  }

  /// Whether two reads hold the same values. Two nulls are the same.
  static bool hasSameValues(DynamicDeviceState? a, DynamicDeviceState? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return mapEquals(a.device.toJson(), b.device.toJson()) &&
        mapEquals(a.network.toJson(), b.network.toJson());
  }

  /// Only the dynamic `meta.device` fields are set.
  final Device device;

  /// Every `meta.network` field is dynamic.
  final Network network;

  static const _thermalStates = {'nominal', 'fair', 'serious', 'critical'};
  static const _connectionTypes = {
    'wifi',
    'cell',
    'wired',
    'unavailable',
    'unknown',
  };

  static int? _percent(Object? value) {
    return value is int && value >= 0 && value <= 100 ? value : null;
  }

  static bool? _bool(Object? value) => value is bool ? value : null;

  static String? _text(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  static String? _oneOf(Object? value, Set<String> allowed) {
    return value is String && allowed.contains(value) ? value : null;
  }
}

/// The values read when a signal was captured. A null [state] means no value
/// was usable at that moment, which differs from no capture at all.
class DynamicDeviceStateCapture {
  const DynamicDeviceStateCapture(this.state);

  final DynamicDeviceState? state;
}

/// Keeps the dynamic device and network values current without blocking.
///
/// Two kinds of value:
/// - **Listener-fed** values (battery, power, thermal and connection type).
///   The native side streams them over the `faro/device_state` event channel.
///   The first event holds the current values and each later one the values
///   after a change, so these never expire.
/// - **Probed** values, which have no listener: the Android carrier name and
///   cellular subtype. iOS has none. [refreshIfStale] reads them again when
///   a signal is captured and they are older than [timeToLive]. The read
///   never blocks the signal, so the signal carries the previous value until
///   the read ends. A value older than [maxStaleAge] is left out. A change of
///   connection type clears the cellular subtype, which belongs to one
///   network, and reads it again at once. The carrier name belongs to the
///   SIM, so it stays.
///
/// All of it lives in memory. A crash recovered on the next launch is sent
/// from its own payload and never reads it.
class DynamicDeviceStateProvider {
  DynamicDeviceStateProvider({
    required FaroNativeMethods nativeMethods,
    required PlatformInfoProvider platformInfoProvider,
    DateTime Function() currentTime = DateTime.now,
    this.timeToLive = defaultTimeToLive,
    this.maxStaleAge = defaultMaxStaleAge,
    this.failureBackoff = defaultFailureBackoff,
    this.firstStateTimeout = defaultFirstStateTimeout,
    Stream<Object?> Function()? openChangeStream,
  }) : _nativeMethods = nativeMethods,
       _isSupported =
           platformInfoProvider.isAndroid || platformInfoProvider.isIOS,
       _hasProbedValues = platformInfoProvider.isAndroid,
       _currentTime = currentTime,
       _openChangeStream =
           openChangeStream ??
           (() =>
               const EventChannel(changeChannelName).receiveBroadcastStream());

  /// The longest a probed value is served before it is read again.
  static const defaultTimeToLive = Duration(seconds: 5);

  /// The longest a probed value is served while a new read runs. It spans two
  /// 30-second vitals ticks, so a periodic signal still carries it.
  static const defaultMaxStaleAge = Duration(seconds: 60);

  /// How long to wait before reading probed values again after a failed read.
  static const defaultFailureBackoff = Duration(seconds: 30);

  /// How long [start] waits for the first listener-fed values.
  static const defaultFirstStateTimeout = Duration(seconds: 2);

  /// The event channel the native side streams listener-fed values on.
  static const changeChannelName = 'faro/device_state';

  /// The probed values that describe one network. A new connection type makes
  /// them wrong, unlike the carrier name.
  static const _networkSpecificKeys = {'connectionSubtype'};

  final Duration timeToLive;
  final Duration maxStaleAge;
  final Duration failureBackoff;
  final Duration firstStateTimeout;
  final FaroNativeMethods _nativeMethods;
  final bool _isSupported;

  /// Only Android has values without a listener.
  final bool _hasProbedValues;
  final DateTime Function() _currentTime;
  final Stream<Object?> Function() _openChangeStream;
  StreamSubscription<Object?>? _changes;

  Map<String, dynamic>? _listened;
  Map<String, dynamic> _probed = const {};
  DateTime? _probedAt;
  DateTime? _retryNotBefore;

  /// Counts connection type changes. A read that began before a change holds
  /// the old network's answer, so its result is dropped.
  int _networkEpoch = 0;
  bool _probedNeedsRead = false;
  Future<void>? _inFlightProbe;

  /// The values to send now, or null before the first read, after a failed
  /// read, or on a platform without native values. A probed value older than
  /// [maxStaleAge] is left out.
  DynamicDeviceState? get current {
    final listened = _listened;
    if (listened == null) {
      return null;
    }
    return DynamicDeviceState.fromNative({
      if (_isProbedUsable) ..._probed,
      ...listened,
    });
  }

  bool get _isProbedFresh {
    final probedAt = _probedAt;
    return probedAt != null &&
        _currentTime().difference(probedAt) <= timeToLive;
  }

  bool get _isProbedUsable {
    final probedAt = _probedAt;
    return probedAt != null &&
        _currentTime().difference(probedAt) <= maxStaleAge;
  }

  /// Starts receiving the listener-fed values and waits for the first ones.
  /// The probed values are read in the background, so a slow network never
  /// delays the caller. When the first values do not arrive within
  /// [firstStateTimeout], the provider has no value until they do. Never
  /// throws.
  Future<void> start() async {
    if (!_isSupported || _changes != null) {
      return;
    }
    final firstState = Completer<void>();
    void completeFirstState() {
      if (!firstState.isCompleted) {
        firstState.complete();
      }
    }

    try {
      _changes = _openChangeStream().listen(
        (event) {
          if (event is Map) {
            applyListened(Map<String, dynamic>.from(event));
            completeFirstState();
          }
        },
        onError: (Object error) {
          log('Faro: Native dynamic device state unavailable: $error');
          completeFirstState();
        },
      );
      await firstState.future.timeout(firstStateTimeout);
    } on TimeoutException {
      log('Faro: Native dynamic device state did not answer in time.');
    } catch (error) {
      log('Faro: Native dynamic device state unavailable: $error');
    }
    if (_listened != null) {
      unawaited(refreshProbed());
    }
  }

  void dispose() {
    unawaited(_changes?.cancel());
    _changes = null;
  }

  /// Replaces the listener-fed values with the latest ones from native.
  @visibleForTesting
  void applyListened(Map<String, dynamic> listened) {
    if (_listened?['connectionType'] != listened['connectionType']) {
      _networkEpoch++;
      _probed = {
        for (final entry in _probed.entries)
          if (!_networkSpecificKeys.contains(entry.key)) entry.key: entry.value,
      };
      _probedNeedsRead = true;
    }
    _listened = listened;
  }

  /// Reads the probed values when they are stale and no read is running.
  /// Never waits.
  void refreshIfStale() {
    final retryNotBefore = _retryNotBefore;
    final isBackingOff =
        retryNotBefore != null && _currentTime().isBefore(retryNotBefore);
    final needsRead = !_isProbedFresh || _probedNeedsRead;
    if (_hasProbedValues && _listened != null && needsRead && !isBackingOff) {
      unawaited(refreshProbed());
    }
  }

  /// Reads the probed values once. Never throws.
  Future<void> refreshProbed() {
    if (!_hasProbedValues) {
      return Future<void>.value();
    }
    return _inFlightProbe ??= _readProbed().whenComplete(() {
      _inFlightProbe = null;
    });
  }

  Future<void> _readProbed() async {
    final startedAt = _currentTime();
    final epoch = _networkEpoch;
    try {
      final native = await _nativeMethods.getProbedDeviceState();
      if (epoch != _networkEpoch) {
        // The network changed while this read ran. Read again on the next
        // signal.
        return;
      }
      _probed = native ?? const {};
      _probedAt = startedAt;
      _probedNeedsRead = false;
      _retryNotBefore = null;
    } catch (error) {
      _probed = const {};
      _probedAt = null;
      _retryNotBefore = _currentTime().add(failureBackoff);
      log('Faro: Native probed device state unavailable: $error');
    }
  }
}

class DynamicDeviceStateProviderFactory {
  DynamicDeviceStateProvider create({
    required FaroNativeMethods nativeMethods,
  }) {
    return DynamicDeviceStateProvider(
      nativeMethods: nativeMethods,
      platformInfoProvider: PlatformInfoProviderFactory().create(),
    );
  }
}
