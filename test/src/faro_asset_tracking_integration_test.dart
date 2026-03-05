import 'package:faro/src/configurations/batch_config.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_asset_bundle.dart';
import 'package:faro/src/faro_asset_tracking.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBaseTransport extends Mock implements BaseTransport {}

class _FakeAssetBundle extends Fake implements AssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return 'fake-content';
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    return ByteData.sublistView(bytes);
  }
}

void main() {
  late _MockBaseTransport mockTransport;
  late Faro faro;

  Future<void> initializeFaro() async {
    await faro.init(
      optionsConfiguration: FaroConfig(
        collectorUrl: 'https://example.com',
        appName: 'test-app',
        appEnv: 'test',
        apiKey: 'test-key',
        batchConfig: BatchConfig(enabled: false),
      ),
    );
    clearInteractions(mockTransport);
  }

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    BatchTransportFactory().reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'test-app',
      packageName: 'com.example.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );

    mockTransport = _MockBaseTransport();
    when(() => mockTransport.send(any())).thenAnswer((_) async {});

    faro = Faro();
    faro.transports = <BaseTransport>[mockTransport];

    pod.overrideProvider<AssetBundle>(
      rootAssetBundleProvider,
      (_) => _FakeAssetBundle(),
    );
  });

  tearDown(() {
    pod.removeOverride(rootAssetBundleProvider);
    BatchTransportFactory().reset();
  });

  testWidgets(
      'asset load through FaroAssetTracking pushes Asset-load event '
      'to transport', (tester) async {
    await initializeFaro();

    late AssetBundle assetBundle;
    await tester.pumpWidget(
      MaterialApp(
        home: FaroAssetTracking(
          child: Builder(
            builder: (context) {
              assetBundle = DefaultAssetBundle.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(assetBundle, isA<FaroAssetBundle>());

    await assetBundle.loadString('assets/config.txt');
    await tester.pump();

    final captured = verify(() => mockTransport.send(captureAny())).captured;

    final hasAssetLoadEvent = captured.any((payload) {
      final events = payload['events'] as List<dynamic>?;
      if (events == null) return false;
      return events.any(
        (e) => e['name'] == 'Asset-load',
      );
    });
    expect(hasAssetLoadEvent, isTrue);
  });

  testWidgets(
      'asset load during active user action emits activity signal '
      'that keeps the action alive', (tester) async {
    await initializeFaro();

    late AssetBundle assetBundle;
    await tester.pumpWidget(
      MaterialApp(
        home: FaroAssetTracking(
          child: Builder(
            builder: (context) {
              assetBundle = DefaultAssetBundle.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final action = faro.startUserAction('asset-load-action');
    expect(action, isNotNull);

    await assetBundle.loadString('assets/data.json');
    await tester.pump(const Duration(milliseconds: 160));

    expect(action!.getState(), UserActionState.ended);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
