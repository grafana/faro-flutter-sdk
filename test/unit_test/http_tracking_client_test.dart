// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:io';

import 'package:faro/src/integrations/http_tracking_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

void main() {
  group('FaroHttpTrackingClient', () {
    late MockHttpClient mockHttpClient;
    late FaroHttpTrackingClient faroHttpTrackingClient;
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpHeaders mockHttpHeaders;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockHttpClientRequest = MockHttpClientRequest();
      mockHttpHeaders = MockHttpHeaders();

      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.headers).thenReturn(mockHttpHeaders);
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));

      faroHttpTrackingClient = FaroHttpTrackingClient(mockHttpClient);
    });

    test('openUrl should call innerClient.openUrl', () async {
      final url = Uri.parse('http://example.com/path');

      when(() => mockHttpClient.openUrl('GET', url))
          .thenAnswer((_) async => mockHttpClientRequest);

      final requestFuture = faroHttpTrackingClient.openUrl('GET', url);

      verify(() => mockHttpClient.openUrl('GET', url)).called(1);

      expect(await requestFuture, isA<HttpClientRequest>());
    });
  });

  group('FaroTrackingHttpClientRequest', () {
    late MockHttpClientRequest mockHttpClientRequest;
    late FaroTrackingHttpClientRequest faroTrackingHttpClientRequest;
    late Map<String, Object?> userAttributes;
    late MockHttpHeaders mockHttpHeaders;

    setUp(() {
      mockHttpClientRequest = MockHttpClientRequest();
      mockHttpHeaders = MockHttpHeaders();

      when(() => mockHttpHeaders.contentLength).thenReturn(100);
      when(() => mockHttpHeaders.contentType).thenReturn(null);
      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.headers).thenReturn(mockHttpHeaders);
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));

      userAttributes = {
        'method': 'GET',
        'url': 'http://example.com/path',
      };
      faroTrackingHttpClientRequest = FaroTrackingHttpClientRequest(
          'key', mockHttpClientRequest, userAttributes);
    });

    test('close should call innerContext.close ', () async {
      final mockHttpClientResponse = MockHttpClientResponse();

      when(() => mockHttpClientRequest.close())
          .thenAnswer((_) async => mockHttpClientResponse);
      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.contentLength).thenReturn(0);
      when(() => mockHttpClientRequest.uri).thenReturn(Uri.http('some.uri'));
      when(() => mockHttpClientResponse.headers).thenReturn(mockHttpHeaders);
      when(() => mockHttpClientResponse.statusCode).thenReturn(200);

      final responseFuture = faroTrackingHttpClientRequest.close();

      verify(() => mockHttpClientRequest.close()).called(1);

      expect(await responseFuture, isA<HttpClientResponse>());
    });
  });
}
