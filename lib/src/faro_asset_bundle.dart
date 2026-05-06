import 'dart:async';

import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/util/short_id.dart';
import 'package:flutter/services.dart';

/// Provides the platform's default [AssetBundle] ([rootBundle]).
final rootAssetBundleProvider = Provider<AssetBundle>((pod) => rootBundle);

/// Provides a [FaroAssetBundle] wired with its required dependencies.
final faroAssetBundleProvider = Provider<AssetBundle>((pod) {
  return FaroAssetBundle(
    bundle: pod.resolve(rootAssetBundleProvider),
    lifecycleSignalChannel: pod.resolve(
      userActionLifecycleSignalChannelProvider,
    ),
  );
});

/// Creates a [FaroAssetBundle] from the dependency container.
class FaroAssetBundleFactory {
  AssetBundle create() => pod.resolve(faroAssetBundleProvider);
}

/// An [AssetBundle] decorator that tracks asset loading performance
/// and emits user-action lifecycle signals.
class FaroAssetBundle extends AssetBundle {
  FaroAssetBundle({
    required AssetBundle bundle,
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
  }) : _bundle = bundle,
       _lifecycleSignalChannel = lifecycleSignalChannel;

  final AssetBundle _bundle;
  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;

  @override
  Future<ByteData> load(String key) =>
      _trackAssetLoad(key, () => _bundle.load(key));

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      _trackAssetLoad(key, () => _bundle.loadString(key, cache: cache));

  @override
  Future<ImmutableBuffer> loadBuffer(String key) =>
      _trackAssetLoad(key, () => _bundle.loadBuffer(key));

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => _trackParsedLoad(
    key,
    (reportSize) => _bundle.loadStructuredData<T>(key, (raw) {
      reportSize(raw.length);
      return parser(raw);
    }),
  );

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => _trackParsedLoad(
    key,
    (reportSize) => _bundle.loadStructuredBinaryData<T>(key, (raw) {
      reportSize(raw.lengthInBytes);
      return parser(raw);
    }),
  );

  Future<T> _trackParsedLoad<T>(
    String key,
    Future<T> Function(void Function(int) reportSize) loader,
  ) async {
    final operationId = generateShortId();
    _lifecycleSignalChannel.emitPendingStart(
      source: UserActionConstants.resourceAssetSignalSource,
      operationId: operationId,
    );

    try {
      int? rawSize;
      final beforeLoad = DateTime.now().millisecondsSinceEpoch;
      final data = await loader((size) => rawSize = size);
      final afterLoad = DateTime.now().millisecondsSinceEpoch;
      final duration = afterLoad - beforeLoad;

      Faro().pushEvent(
        'Asset-load',
        attributes: {'name': key, 'size': '$rawSize', 'duration': '$duration'},
      );
      return data;
    } finally {
      _lifecycleSignalChannel.emitPendingEnd(
        source: UserActionConstants.resourceAssetSignalSource,
        operationId: operationId,
      );
    }
  }

  Future<T> _trackAssetLoad<T>(String key, Future<T> Function() loader) async {
    final operationId = generateShortId();
    _lifecycleSignalChannel.emitPendingStart(
      source: UserActionConstants.resourceAssetSignalSource,
      operationId: operationId,
    );

    try {
      final beforeLoad = DateTime.now().millisecondsSinceEpoch;
      final data = await loader();
      final afterLoad = DateTime.now().millisecondsSinceEpoch;
      final duration = afterLoad - beforeLoad;
      final dataSize = _getDataLength(data);
      Faro().pushEvent(
        'Asset-load',
        attributes: {'name': key, 'size': '$dataSize', 'duration': '$duration'},
      );
      return data;
    } finally {
      _lifecycleSignalChannel.emitPendingEnd(
        source: UserActionConstants.resourceAssetSignalSource,
        operationId: operationId,
      );
    }
  }

  int? _getDataLength(dynamic data) {
    if (data is ByteData) {
      return data.lengthInBytes;
    } else if (data is List<int>) {
      return data.length;
    } else if (data is ImmutableBuffer) {
      return data.length;
    } else if (data is String) {
      return data.length;
    }
    return null;
  }
}
