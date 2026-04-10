import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:faro/src/faro_asset_bundle.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action.dart';
import 'package:faro/src/user_actions/user_action_controller.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_signal.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle({this.throwOnLoad = false, this.throwOnLoadString = false});

  final bool throwOnLoad;
  final bool throwOnLoadString;

  @override
  Future<ByteData> load(String key) async {
    if (throwOnLoad) {
      throw Exception('load failed');
    }
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (throwOnLoadString) {
      throw Exception('loadString failed');
    }
    return 'hello';
  }

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    return ImmutableBuffer.fromUint8List(bytes);
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async {
    return parser('structured-data');
  }

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    return parser(ByteData.sublistView(bytes));
  }
}

class _DelayedAssetBundle extends AssetBundle {
  _DelayedAssetBundle(this.loadStringCompleter);

  final Completer<String> loadStringCompleter;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    return loadStringCompleter.future;
  }
}

void main() {
  group('FaroAssetBundle user-action lifecycle signals:', () {
    late UserActionLifecycleSignalChannel signalChannel;
    late List<UserActionSignal> emittedSignals;

    setUp(() {
      signalChannel = UserActionLifecycleSignalChannel();
      emittedSignals = <UserActionSignal>[];
      signalChannel.stream.listen(emittedSignals.add);
    });

    tearDown(() {
      signalChannel.dispose();
    });

    test('load emits pending lifecycle signals', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      await bundle.load('assets/logo.png');
      await Future<void>.delayed(Duration.zero);

      expect(emittedSignals, hasLength(2));
      expect(emittedSignals[0].type, UserActionSignalType.pendingStart);
      expect(
        emittedSignals[0].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].type, UserActionSignalType.pendingEnd);
      expect(
        emittedSignals[1].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].operationId, emittedSignals[0].operationId);
    });

    test('load emits pending signals even when asset loading throws', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(throwOnLoad: true),
        lifecycleSignalChannel: signalChannel,
      );

      await expectLater(
        () => bundle.load('assets/missing.png'),
        throwsException,
      );
      await Future<void>.delayed(Duration.zero);

      expect(emittedSignals, hasLength(2));
      expect(emittedSignals[0].type, UserActionSignalType.pendingStart);
      expect(emittedSignals[1].type, UserActionSignalType.pendingEnd);
      expect(emittedSignals[1].operationId, emittedSignals[0].operationId);
    });

    test('loadString emits pending lifecycle signals', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      await bundle.loadString('assets/config.txt');
      await Future<void>.delayed(Duration.zero);

      expect(emittedSignals, hasLength(2));
      expect(emittedSignals[0].type, UserActionSignalType.pendingStart);
      expect(
        emittedSignals[0].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].type, UserActionSignalType.pendingEnd);
      expect(
        emittedSignals[1].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].operationId, emittedSignals[0].operationId);
    });

    test('load returns the data from the underlying bundle', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      final result = await bundle.load('assets/logo.png');

      expect(
        result.buffer.asUint8List(),
        Uint8List.fromList(<int>[1, 2, 3, 4]),
      );
    });

    test('loadString returns the data from the underlying bundle', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      final result = await bundle.loadString('assets/config.txt');

      expect(result, 'hello');
    });

    test(
      'loadString emits pending signals even when asset loading throws',
      () async {
        final bundle = FaroAssetBundle(
          bundle: _FakeAssetBundle(throwOnLoadString: true),
          lifecycleSignalChannel: signalChannel,
        );

        await expectLater(
          () => bundle.loadString('assets/missing.txt'),
          throwsException,
        );
        await Future<void>.delayed(Duration.zero);

        expect(emittedSignals, hasLength(2));
        expect(emittedSignals[0].type, UserActionSignalType.pendingStart);
        expect(emittedSignals[1].type, UserActionSignalType.pendingEnd);
        expect(emittedSignals[1].operationId, emittedSignals[0].operationId);
      },
    );

    test('loadStructuredData emits pending lifecycle signals', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      final value = await bundle.loadStructuredData<String>(
        'assets/config.json',
        (data) async => data,
      );
      await Future<void>.delayed(Duration.zero);

      expect(value, 'structured-data');
      expect(emittedSignals, hasLength(2));
      expect(emittedSignals[0].type, UserActionSignalType.pendingStart);
      expect(
        emittedSignals[0].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].type, UserActionSignalType.pendingEnd);
      expect(
        emittedSignals[1].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].operationId, emittedSignals[0].operationId);
    });

    test('loadStructuredData passes raw string to parser and returns '
        'the parsed result', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      String? receivedRawString;
      final result = await bundle.loadStructuredData<List<String>>(
        'assets/data.csv',
        (rawString) async {
          receivedRawString = rawString;
          return rawString.split('-');
        },
      );

      expect(receivedRawString, 'structured-data');
      expect(result, ['structured', 'data']);
    });

    test('loadBuffer returns the data from the underlying bundle', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      final result = await bundle.loadBuffer('assets/image.png');

      expect(result.length, 4);
    });

    test('loadBuffer emits pending lifecycle signals', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      await bundle.loadBuffer('assets/image.png');
      await Future<void>.delayed(Duration.zero);

      expect(emittedSignals, hasLength(2));
      expect(emittedSignals[0].type, UserActionSignalType.pendingStart);
      expect(
        emittedSignals[0].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].type, UserActionSignalType.pendingEnd);
      expect(
        emittedSignals[1].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].operationId, emittedSignals[0].operationId);
    });

    test('loadStructuredBinaryData passes raw data to parser and '
        'returns the parsed result', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      ByteData? receivedData;
      final result = await bundle.loadStructuredBinaryData<int>(
        'assets/data.bin',
        (data) {
          receivedData = data;
          return data.lengthInBytes;
        },
      );

      expect(receivedData!.lengthInBytes, 4);
      expect(result, 4);
    });

    test('loadStructuredBinaryData emits pending lifecycle signals', () async {
      final bundle = FaroAssetBundle(
        bundle: _FakeAssetBundle(),
        lifecycleSignalChannel: signalChannel,
      );

      await bundle.loadStructuredBinaryData<int>(
        'assets/data.bin',
        (data) => data.lengthInBytes,
      );
      await Future<void>.delayed(Duration.zero);

      expect(emittedSignals, hasLength(2));
      expect(emittedSignals[0].type, UserActionSignalType.pendingStart);
      expect(
        emittedSignals[0].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].type, UserActionSignalType.pendingEnd);
      expect(
        emittedSignals[1].source,
        UserActionConstants.resourceAssetSignalSource,
      );
      expect(emittedSignals[1].operationId, emittedSignals[0].operationId);
    });

    test('long asset load keeps a user action alive until completion', () {
      fakeAsync((async) {
        final loadStringCompleter = Completer<String>();
        final action = UserAction(name: 'asset-load-action', trigger: 'test');
        final controller = UserActionLifecycleController(
          action,
          signalChannel.stream,
        );
        final bundle = FaroAssetBundle(
          bundle: _DelayedAssetBundle(loadStringCompleter),
          lifecycleSignalChannel: signalChannel,
        );

        controller.attach();
        unawaited(bundle.loadString('assets/slow-config.txt'));
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 160));
        expect(action.getState(), UserActionState.halted);

        loadStringCompleter.complete('hello');
        async.flushMicrotasks();

        expect(action.getState(), UserActionState.ended);

        controller.dispose();
        action.dispose();
      });
    });
  });
}
