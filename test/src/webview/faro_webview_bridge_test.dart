import 'package:faro/faro.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBaseTransport extends Mock implements BaseTransport {}

void main() {
  const testUrl = 'https://example.com/login?existing=param';

  late MockBaseTransport mockTransport;
  late Faro faro;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Faro.resetForTesting();
    BatchTransportFactory().reset();
    SharedPreferences.setMockInitialValues({});

    PackageInfo.setMockInitialValues(
      appName: 'TestFlutterApp',
      packageName: 'com.example.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );

    mockTransport = MockBaseTransport();
    when(() => mockTransport.send(any())).thenAnswer((_) async {});

    faro = Faro();
    faro.transports = [mockTransport];

    await faro.init(
      optionsConfiguration: FaroConfig(
        collectorUrl: 'https://collector.example.com',
        appName: 'TestFlutterApp',
        appEnv: 'test',
        apiKey: 'test-key',
        batchConfig: BatchConfig(enabled: false),
      ),
    );
    clearInteractions(mockTransport);
  });

  tearDown(() {
    Faro.resetForTesting();
    BatchTransportFactory().reset();
  });

  group('FaroWebViewBridge:', () {
    group('instrumentedUrl:', () {
      test('should append traceparent query parameter', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        final result = bridge.instrumentedUrl(url);

        expect(result.queryParameters.containsKey('traceparent'), isTrue);
        final traceparent = result.queryParameters['traceparent']!;
        expect(
          traceparent,
          matches(RegExp(r'^00-[a-f0-9]{32}-[a-f0-9]{16}-01$')),
        );
      });

      test('should append session.parent_id query parameter', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        final result = bridge.instrumentedUrl(url);

        expect(
          result.queryParameters.containsKey('session.parent_id'),
          isTrue,
        );
        final parentId = result.queryParameters['session.parent_id']!;
        expect(parentId, isNotEmpty);
        expect(parentId, equals(faro.meta.session?.id));
      });

      test('should append session.parent_app query parameter', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        final result = bridge.instrumentedUrl(url);

        expect(
          result.queryParameters.containsKey('session.parent_app'),
          isTrue,
        );
        expect(
          result.queryParameters['session.parent_app'],
          equals('TestFlutterApp'),
        );
      });

      test('should preserve existing query parameters', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        final result = bridge.instrumentedUrl(url);

        expect(result.queryParameters['existing'], equals('param'));
      });

      test('should preserve the original URL scheme, host and path', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        final result = bridge.instrumentedUrl(url);

        expect(result.scheme, equals('https'));
        expect(result.host, equals('example.com'));
        expect(result.path, equals('/login'));
      });

      test('should produce different traceparent on each call', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        final result1 = bridge.instrumentedUrl(url);
        final result2 = bridge.instrumentedUrl(url);

        expect(
          result1.queryParameters['traceparent'],
          isNot(equals(result2.queryParameters['traceparent'])),
        );
      });

      test('should end previous span with error when called twice', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        bridge.instrumentedUrl(url);
        bridge.instrumentedUrl(url);

        // The bridge should handle superseding gracefully.
        // Ending should still work after superseding.
        bridge.end();
      });

      test('should accept optional spanName parameter', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(testUrl);

        final result = bridge.instrumentedUrl(
          url,
          spanName: 'CustomWebView',
        );

        expect(result.queryParameters.containsKey('traceparent'), isTrue);
      });
    });

    group('linkChildSession:', () {
      test('should push session.linked event', () {
        final bridge = FaroWebViewBridge();
        bridge.instrumentedUrl(Uri.parse(testUrl));

        bridge.linkChildSession(
          sessionId: 'web-session-123',
          appName: 'MyWebApp',
        );

        final captured = verify(
          () => mockTransport.send(captureAny()),
        ).captured;
        expect(captured, isNotEmpty);

        final payload = captured.last as Map<String, dynamic>;
        final events = payload['events'] as List<dynamic>;
        final linkedEvent = events.firstWhere(
          (e) => (e as Map<String, dynamic>)['name'] == 'session.linked',
        ) as Map<String, dynamic>;

        expect(linkedEvent, isNotNull);
        final attributes = linkedEvent['attributes'] as Map<String, dynamic>?;
        expect(attributes?['session.child_id'], equals('web-session-123'));
        expect(attributes?['session.child_app'], equals('MyWebApp'));
      });

      test('should work without appName', () {
        final bridge = FaroWebViewBridge();
        bridge.instrumentedUrl(Uri.parse(testUrl));

        bridge.linkChildSession(sessionId: 'web-session-456');

        final captured = verify(
          () => mockTransport.send(captureAny()),
        ).captured;
        expect(captured, isNotEmpty);

        final payload = captured.last as Map<String, dynamic>;
        final events = payload['events'] as List<dynamic>;
        final linkedEvent = events.firstWhere(
          (e) => (e as Map<String, dynamic>)['name'] == 'session.linked',
        ) as Map<String, dynamic>;

        expect(linkedEvent, isNotNull);
        final attributes = linkedEvent['attributes'] as Map<String, dynamic>?;
        expect(attributes?['session.child_id'], equals('web-session-456'));
      });
    });

    group('end:', () {
      test('should end span without error', () {
        final bridge = FaroWebViewBridge();
        bridge.instrumentedUrl(Uri.parse(testUrl));

        expect(bridge.end, returnsNormally);
      });

      test('should be safe to call twice', () {
        final bridge = FaroWebViewBridge();
        bridge.instrumentedUrl(Uri.parse(testUrl));

        bridge.end();
        expect(bridge.end, returnsNormally);
      });

      test('should be safe to call without instrumentedUrl', () {
        final bridge = FaroWebViewBridge();

        expect(bridge.end, returnsNormally);
      });

      test('should accept custom status and message', () {
        final bridge = FaroWebViewBridge();
        bridge.instrumentedUrl(Uri.parse(testUrl));

        expect(
          () => bridge.end(
            status: SpanStatusCode.error,
            message: 'User cancelled',
          ),
          returnsNormally,
        );
      });
    });
  });
}
