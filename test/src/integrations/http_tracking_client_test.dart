import 'dart:io';

import 'package:faro/src/integrations/http_tracking_client.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/tracing/span.dart';
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
    late FaroHttpTrackingClient client;
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpHeaders mockRequestHeaders;

    setUp(() {
      mockHttpClient = MockHttpClient();
      trackingFilter = HttpTrackingFilter();
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
      );
    });

    test('should bypass tracking when filter rejects URL', () async {
      trackingFilter.configure(
        collectorUrl: 'http://example.com/path',
        ignoreUrls: null,
      );

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenAnswer((_) async => mockHttpClientRequest);

      final request = await client.openUrl('GET', url);

      expect(request, same(mockHttpClientRequest));
      verify(() => mockHttpClient.openUrl('GET', url)).called(1);
    });

    test('should wrap request when tracked', () async {
      trackingFilter.configure(collectorUrl: null, ignoreUrls: null);

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenAnswer((_) async => mockHttpClientRequest);

      final request = await client.openUrl('GET', url);
      await Future<void>.delayed(Duration.zero);

      expect(request, isA<FaroTrackingHttpClientRequest>());
    });

    test('should rethrow when opening tracked request throws', () async {
      trackingFilter.configure(collectorUrl: null, ignoreUrls: null);

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenThrow(const SocketException('boom'));

      await expectLater(
        () => client.openUrl('GET', url),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('FaroTrackingHttpClientRequest:', () {
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpClientResponse mockHttpClientResponse;
    late MockHttpHeaders mockRequestHeaders;
    late MockHttpHeaders mockResponseHeaders;
    late FaroTrackingHttpClientRequest trackedRequest;
    late MockSpan mockSpan;

    setUp(() {
      mockHttpClientRequest = MockHttpClientRequest();
      mockHttpClientResponse = MockHttpClientResponse();
      mockRequestHeaders = MockHttpHeaders();
      mockResponseHeaders = MockHttpHeaders();
      mockSpan = MockSpan();

      when(() => mockSpan.traceId).thenReturn('trace-id');
      when(() => mockSpan.spanId).thenReturn('span-id');
      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));
      when(() => mockHttpClientRequest.contentLength).thenReturn(42);
      when(() => mockHttpClientRequest.headers).thenReturn(mockRequestHeaders);

      trackedRequest = FaroTrackingHttpClientRequest(
        mockHttpClientRequest,
        httpSpan: mockSpan,
      );
    });

    test('close should end span on success when response completes', () async {
      when(() => mockHttpClientRequest.close())
          .thenAnswer((_) async => mockHttpClientResponse);
      when(() => mockHttpClientResponse.statusCode).thenReturn(200);
      when(() => mockHttpClientResponse.headers)
          .thenReturn(mockResponseHeaders);
      when(() => mockResponseHeaders.contentLength).thenReturn(128);
      when(() => mockResponseHeaders.contentType).thenReturn(null);
      when(
        () => mockHttpClientResponse.listen(
          any(),
          onError: any(named: 'onError'),
          onDone: any(named: 'onDone'),
          cancelOnError: any(named: 'cancelOnError'),
        ),
      ).thenAnswer((invocation) {
        final onDone = invocation.namedArguments[#onDone] as void Function()?;
        onDone?.call();
        return const Stream<List<int>>.empty().listen(null);
      });

      final response = await trackedRequest.close();
      verifyNever(() => mockSpan.end());
      response.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(response, isA<HttpClientResponse>());
      verify(() => mockSpan.setStatus(SpanStatusCode.ok)).called(1);
      verify(() => mockSpan.end()).called(1);
    });

    test('close should end span on error', () async {
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
    });
  });
}
