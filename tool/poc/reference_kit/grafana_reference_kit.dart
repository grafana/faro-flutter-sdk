import 'dart:async';

/// Adds Grafana behavior to a telemetry SDK without wrapping its native API.
abstract interface class GrafanaReferenceKitPlugin<TSdk extends Object> {
  /// Installs this plugin on [sdk].
  FutureOr<void> start(TSdk sdk);

  /// Removes this plugin from [sdk].
  FutureOr<void> stop(TSdk sdk);
}

/// A composition-first proof of concept for the Flutter Reference Kit.
///
/// The native [sdk] remains public so applications can use its complete API.
/// Grafana-specific behavior is added through small lifecycle plugins instead
/// of a wrapper that mirrors every SDK method.
final class GrafanaReferenceKit<TSdk extends Object> {
  GrafanaReferenceKit({
    required this.sdk,
    required List<GrafanaReferenceKitPlugin<TSdk>> plugins,
  }) : _plugins = List.unmodifiable(plugins);

  /// The unwrapped telemetry SDK supplied by the application.
  final TSdk sdk;

  final List<GrafanaReferenceKitPlugin<TSdk>> _plugins;
  final List<GrafanaReferenceKitPlugin<TSdk>> _startedPlugins = [];
  _ReferenceKitState _state = _ReferenceKitState.idle;

  /// Whether every plugin started successfully.
  bool get isRunning => _state == _ReferenceKitState.running;

  /// Starts each plugin in registration order.
  ///
  /// A repeated call after successful startup has no effect. If startup fails,
  /// plugins that already started are stopped in reverse order before the
  /// original error is rethrown.
  Future<void> start() async {
    if (_state == _ReferenceKitState.running) {
      return;
    }
    if (_state != _ReferenceKitState.idle) {
      throw StateError('Reference Kit lifecycle change already in progress.');
    }

    _state = _ReferenceKitState.starting;
    try {
      for (final plugin in _plugins) {
        _startedPlugins.add(plugin);
        await plugin.start(sdk);
      }
      _state = _ReferenceKitState.running;
    } catch (error, stackTrace) {
      await _stopStartedPlugins(ignoreErrors: true);
      _state = _ReferenceKitState.idle;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Stops each installed plugin in reverse order.
  ///
  /// Cleanup continues after an individual plugin fails. The first cleanup
  /// error is rethrown after all plugins have had a chance to stop.
  Future<void> stop() async {
    if (_state == _ReferenceKitState.idle) {
      return;
    }
    if (_state != _ReferenceKitState.running) {
      throw StateError('Reference Kit lifecycle change already in progress.');
    }

    _state = _ReferenceKitState.stopping;
    final failure = await _stopStartedPlugins(ignoreErrors: false);
    _state = _ReferenceKitState.idle;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  Future<_PluginFailure?> _stopStartedPlugins({
    required bool ignoreErrors,
  }) async {
    _PluginFailure? firstFailure;
    for (final plugin in _startedPlugins.reversed) {
      try {
        await plugin.stop(sdk);
      } catch (error, stackTrace) {
        firstFailure ??= _PluginFailure(error, stackTrace);
      }
    }
    _startedPlugins.clear();
    return ignoreErrors ? null : firstFailure;
  }
}

enum _ReferenceKitState { idle, starting, running, stopping }

final class _PluginFailure {
  const _PluginFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
