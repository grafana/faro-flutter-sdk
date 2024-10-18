import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/transport/batch_transport.dart';

class MockHttpClient extends Mock implements HttpClient {}
class MockHttpClientRequest extends Mock implements HttpClientRequest {}
class MockHttpClientResponse extends Mock implements HttpClientResponse {}
class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

void main() {
  group('RumHttpTrackingClient', () {
    late MockHttpClient mockHttpClient;
    late RumHttpTrackingClient rumHttpTrackingClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      rumHttpTrackingClient = RumHttpTrackingClient(mockHttpClient);
    });


    test('openUrl should call innerClient.openUrl', () async {
      final mockHttpClientRequest = MockHttpClientRequest();
      final url = Uri.parse('http://example.com/path');

      when(() => mockHttpClient.openUrl('GET', url)).thenAnswer((_) async => mockHttpClientRequest);

      final requestFuture = rumHttpTrackingClient.openUrl('GET', url);

      verify(() => mockHttpClient.openUrl('GET', url)).called(1);

      expect(await requestFuture, isA<HttpClientRequest>());
    });
  });

  group('RumTrackingHttpClientRequest', () {
    late MockHttpClientRequest mockHttpClientRequest;
    late RumTrackingHttpClientRequest rumTrackingHttpClientRequest;
    late Map<String, Object?> userAttributes;

    setUp(() {
      mockHttpClientRequest = MockHttpClientRequest();
      userAttributes = {
        'method': 'GET',
        'url': 'http://example.com/path',
      };
      rumTrackingHttpClientRequest = RumTrackingHttpClientRequest('key', mockHttpClientRequest, userAttributes);
    });

    test('close should call innerContext.close ', () async {
      final mockHttpClientResponse = MockHttpClientResponse();
      when(() => mockHttpClientRequest.close()).thenAnswer((_) async => mockHttpClientResponse);

      final responseFuture = rumTrackingHttpClientRequest.close();


      verify(() => mockHttpClientRequest.close()).called(1);

      expect(await responseFuture, isA<HttpClientResponse>());
    });

  });
}

