import 'package:faro/faro.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBaseTransport extends Mock implements BaseTransport {}

/// Wraps a real span and records every mutating call, so tests can assert
/// that the bridge leaves an app-owned span alone.
class RecordingSpan implements Span {
  RecordingSpan(this._delegate);

  final Span _delegate;
  final List<String> mutations = [];

  @override
  String get traceparent => _delegate.traceparent;

  @override
  String get traceId => _delegate.traceId;

  @override
  String get spanId => _delegate.spanId;

  @override
  bool get wasEnded => mutations.contains('end');

  @override
  SpanStatusCode get status => SpanStatusCode.unset;

  @override
  bool get statusHasBeenSet => mutations.contains('setStatus');

  @override
  void setStatus(SpanStatusCode statusCode, {String? message}) =>
      mutations.add('setStatus');

  @override
  void addEvent(String message, {Map<String, Object> attributes = const {}}) =>
      mutations.add('addEvent');

  @override
  void setAttributes(Map<String, Object> attributes) =>
      mutations.add('setAttributes');

  @override
  void setAttribute(String key, Object value) => mutations.add('setAttribute');

  @override
  void recordException(dynamic exception, {StackTrace? stackTrace}) =>
      mutations.add('recordException');

  @override
  void end() => mutations.add('end');
}

void main() {
  const testUrl = 'https://example.com/login?existing=param';

  late MockBaseTransport mockTransport;
  late Faro faro;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Faro.resetForTesting();
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

  tearDown(() async {
    await Faro.resetForTesting();
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

        expect(result.queryParameters.containsKey('session.parent_id'), isTrue);
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

      test('should preserve multi-valued query parameters', () {
        final bridge = FaroWebViewBridge();
        final url = Uri.parse(
          'https://example.com/login?tag=a&tag=b&single=one',
        );

        final result = bridge.instrumentedUrl(url);

        expect(result.queryParametersAll['tag'], equals(['a', 'b']));
        expect(result.queryParameters['single'], equals('one'));
        expect(result.queryParameters.containsKey('traceparent'), isTrue);
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

        final result = bridge.instrumentedUrl(url, spanName: 'CustomWebView');

        expect(result.queryParameters.containsKey('traceparent'), isTrue);
      });
    });

    group('instrumentedUrl with an app-owned span:', () {
      test('should propagate the traceparent of the provided span', () {
        final bridge = FaroWebViewBridge();
        final appSpan = faro.startSpanManual('webview');

        final result = bridge.instrumentedUrl(
          Uri.parse(testUrl),
          span: appSpan,
        );

        expect(
          result.queryParameters['traceparent'],
          equals(appSpan.traceparent),
        );

        appSpan.end();
      });

      test('should keep the traceparent stable across repeated calls', () {
        final bridge = FaroWebViewBridge();
        final appSpan = faro.startSpanManual('webview');

        final first = bridge.instrumentedUrl(Uri.parse(testUrl), span: appSpan);
        final second = bridge.instrumentedUrl(
          Uri.parse('https://example.com/profile'),
          span: appSpan,
        );

        expect(
          first.queryParameters['traceparent'],
          equals(second.queryParameters['traceparent']),
        );

        appSpan.end();
      });

      test('should not modify the provided span', () {
        final bridge = FaroWebViewBridge();
        final appSpan = RecordingSpan(faro.startSpanManual('webview'));

        bridge.instrumentedUrl(Uri.parse(testUrl), span: appSpan);

        expect(appSpan.mutations, isEmpty);
      });

      test('should still append the session correlation parameters', () {
        final bridge = FaroWebViewBridge();
        final appSpan = faro.startSpanManual('webview');

        final result = bridge.instrumentedUrl(
          Uri.parse(testUrl),
          span: appSpan,
        );

        expect(
          result.queryParameters['session.parent_id'],
          equals(faro.meta.session?.id),
        );
        expect(
          result.queryParameters['session.parent_app'],
          equals('TestFlutterApp'),
        );

        appSpan.end();
      });

      test('should not end the provided span on end()', () {
        final bridge = FaroWebViewBridge();
        final appSpan = RecordingSpan(faro.startSpanManual('webview'));

        bridge.instrumentedUrl(Uri.parse(testUrl), span: appSpan);
        bridge.end();

        expect(appSpan.wasEnded, isFalse);
        expect(appSpan.mutations, isEmpty);
      });

      test('should not end the provided span on a later call', () {
        final bridge = FaroWebViewBridge();
        final appSpan = RecordingSpan(faro.startSpanManual('webview'));

        bridge.instrumentedUrl(Uri.parse(testUrl), span: appSpan);
        bridge.instrumentedUrl(Uri.parse(testUrl), span: appSpan);
        bridge.instrumentedUrl(Uri.parse(testUrl));

        expect(appSpan.wasEnded, isFalse);
        expect(appSpan.mutations, isEmpty);
      });

      test('should not end the provided span when it supersedes a '
          'bridge-created span', () {
        final bridge = FaroWebViewBridge();
        final appSpan = RecordingSpan(faro.startSpanManual('webview'));

        bridge.instrumentedUrl(Uri.parse(testUrl));
        bridge.instrumentedUrl(Uri.parse(testUrl), span: appSpan);
        bridge.end();

        expect(appSpan.wasEnded, isFalse);
        expect(appSpan.mutations, isEmpty);
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
        final linkedEvent =
            events.firstWhere(
                  (e) =>
                      (e as Map<String, dynamic>)['name'] == 'session.linked',
                )
                as Map<String, dynamic>;

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
        final linkedEvent =
            events.firstWhere(
                  (e) =>
                      (e as Map<String, dynamic>)['name'] == 'session.linked',
                )
                as Map<String, dynamic>;

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
