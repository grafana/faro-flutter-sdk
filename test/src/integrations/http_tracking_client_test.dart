import 'dart:io';

import 'package:faro/src/integrations/http_tracking_client.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_signal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

class MockSpan extends Mock implements Span {}

void main() {
  group('FaroHttpTrackingClient:', () {
    late MockHttpClient mockHttpClient;
    late HttpTrackingFilter trackingFilter;
    late UserActionLifecycleSignalChannel signalChannel;
    late FaroHttpTrackingClient client;
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpHeaders mockRequestHeaders;

    setUp(() {
      mockHttpClient = MockHttpClient();
      trackingFilter = HttpTrackingFilter();
      signalChannel = UserActionLifecycleSignalChannel();
      mockHttpClientRequest = MockHttpClientRequest();
      mockRequestHeaders = MockHttpHeaders();

      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.headers).thenReturn(mockRequestHeaders);
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));
      when(() => mockRequestHeaders.add(any(), any())).thenReturn(null);

      client = FaroHttpTrackingClient(
        mockHttpClient,
        trackingFilter: trackingFilter,
        lifecycleSignalChannel: signalChannel,
      );
    });

    tearDown(() {
      signalChannel.dispose();
    });

    test('should bypass tracking when filter rejects URL', () async {
      trackingFilter.configure(
        collectorUrl: 'http://example.com/path',
        ignoreUrls: null,
      );

      final emittedSignals = <UserActionSignal>[];
      final subscription = signalChannel.stream.listen(emittedSignals.add);

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenAnswer((_) async => mockHttpClientRequest);

      final request = await client.openUrl('GET', url);

      expect(request, same(mockHttpClientRequest));
      expect(emittedSignals, isEmpty);
      verify(() => mockHttpClient.openUrl('GET', url)).called(1);

      await subscription.cancel();
    });

    test('should emit pendingStart and wrap request when tracked', () async {
      trackingFilter.configure(collectorUrl: null, ignoreUrls: null);

      final emittedSignals = <UserActionSignal>[];
      final subscription = signalChannel.stream.listen(emittedSignals.add);

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenAnswer((_) async => mockHttpClientRequest);

      final request = await client.openUrl('GET', url);
      await Future<void>.delayed(Duration.zero);

      expect(request, isA<FaroTrackingHttpClientRequest>());
      expect(emittedSignals.length, equals(1));
      expect(emittedSignals.single.type, UserActionSignalType.pendingStart);
      expect(emittedSignals.single.source, equals('http'));
      expect(emittedSignals.single.operationId, isNotNull);

      await subscription.cancel();
    });

    test('should emit pendingEnd when opening tracked request throws',
        () async {
      trackingFilter.configure(collectorUrl: null, ignoreUrls: null);

      final emittedSignals = <UserActionSignal>[];
      final subscription = signalChannel.stream.listen(emittedSignals.add);

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenThrow(const SocketException('boom'));

      await expectLater(
        () => client.openUrl('GET', url),
        throwsA(isA<SocketException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        emittedSignals.map((signal) => signal.type),
        equals([
          UserActionSignalType.pendingStart,
          UserActionSignalType.pendingEnd,
        ]),
      );
      expect(
        emittedSignals[0].operationId,
        equals(emittedSignals[1].operationId),
      );

      await subscription.cancel();
    });
  });

  group('FaroTrackingHttpClientRequest:', () {
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpClientResponse mockHttpClientResponse;
    late MockHttpHeaders mockRequestHeaders;
    late MockHttpHeaders mockResponseHeaders;
    late UserActionLifecycleSignalChannel signalChannel;
    late FaroTrackingHttpClientRequest trackedRequest;
    late MockSpan mockSpan;

    setUp(() {
      mockHttpClientRequest = MockHttpClientRequest();
      mockHttpClientResponse = MockHttpClientResponse();
      mockRequestHeaders = MockHttpHeaders();
      mockResponseHeaders = MockHttpHeaders();
      signalChannel = UserActionLifecycleSignalChannel();
      mockSpan = MockSpan();

      when(() => mockSpan.traceId).thenReturn('trace-id');
      when(() => mockSpan.spanId).thenReturn('span-id');
      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));
      when(() => mockHttpClientRequest.contentLength).thenReturn(42);
      when(() => mockHttpClientRequest.headers).thenReturn(mockRequestHeaders);

      trackedRequest = FaroTrackingHttpClientRequest(
        'mark-key',
        mockHttpClientRequest,
        httpSpan: mockSpan,
        requestId: 'req-123',
        lifecycleSignalChannel: signalChannel,
      );
    });

    tearDown(() {
      signalChannel.dispose();
    });

    test('close should end span and emit pendingEnd on success', () async {
      final emittedSignals = <UserActionSignal>[];
      final subscription = signalChannel.stream.listen(emittedSignals.add);

      when(() => mockHttpClientRequest.close())
          .thenAnswer((_) async => mockHttpClientResponse);
      when(() => mockHttpClientResponse.statusCode).thenReturn(200);
      when(() => mockHttpClientResponse.headers)
          .thenReturn(mockResponseHeaders);
      when(() => mockResponseHeaders.contentLength).thenReturn(128);
      when(() => mockResponseHeaders.contentType).thenReturn(null);

      final response = await trackedRequest.close();
      await Future<void>.delayed(Duration.zero);

      expect(response, isA<HttpClientResponse>());
      verify(() => mockSpan.setStatus(SpanStatusCode.ok)).called(1);
      verify(() => mockSpan.end()).called(1);
      expect(emittedSignals.length, equals(1));
      expect(emittedSignals.single.type, UserActionSignalType.pendingEnd);
      expect(emittedSignals.single.operationId, equals('req-123'));

      await subscription.cancel();
    });

    test('close should end span and emit pendingEnd on error', () async {
      final emittedSignals = <UserActionSignal>[];
      final subscription = signalChannel.stream.listen(emittedSignals.add);

      when(() => mockHttpClientRequest.close())
          .thenThrow(const SocketException('close failed'));

      await expectLater(
        trackedRequest.close,
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockSpan.setStatus(
          SpanStatusCode.error,
          message: any(named: 'message'),
        ),
      ).called(1);
      verify(() => mockSpan.end()).called(1);
      expect(emittedSignals.length, equals(1));
      expect(emittedSignals.single.type, UserActionSignalType.pendingEnd);
      expect(emittedSignals.single.operationId, equals('req-123'));

      await subscription.cancel();
    });
  });
}
